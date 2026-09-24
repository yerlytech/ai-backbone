#!/usr/bin/env bash
# The backbone's own test. It builds throwaway projects in a temp folder,
# adopts an existing repo, and checks what a person would see.
# Run it with:  just self-test
# Every check prints ok or FAIL; the script exits 1 if anything failed.
set -uo pipefail
# git hands a hook its own GIT_DIR and GIT_INDEX_FILE, and this suite runs as a
# hook on every commit that touches the core. From a linked worktree those point
# into the real repository, so every `git init`, `git add` and `git remote` the
# throwaway projects below run landed there instead of in the temp folder: it
# turned this repository bare and took its GitHub address, once (3.20.0).
# Whatever git exported, the suite starts without it.
unset $(git rev-parse --local-env-vars 2>/dev/null) 2>/dev/null || true
root="$(cd "$(dirname "$0")/.." && pwd -P)"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export AI_BACKBONE="$root"
export AI_BACKBONE_OFFLINE=1   # never reach GitHub or a registry from a test
# Nor the real usage meter, the real transcripts or the real temp folder: the
# session line reads these (spec 014), and the budget section points them at its
# own fixtures. Until then: no meter, no transcripts, one quiet line.
export AI_BACKBONE_BUDGET_PROJECTS="$tmp/no-projects" AI_BACKBONE_BUDGET_METER="$tmp/no-meter" AI_BACKBONE_BUDGET_CACHE="$tmp/budget-cache.json"
mkdir -p "$tmp/T"; export TMPDIR="$tmp/T"
# Nor does a test read or write this machine's own git settings: the place for
# second copies of brain/ lives there, and a doctor run in a throwaway project
# would look into the real one. git is pointed at a file in the temp folder that
# includes the real one, so the name and e-mail the commits below need are still
# found, while `git config --global` reads and writes the temp file only
# (includes are not followed when one file is asked for; measured on git 2.55).
export GIT_CONFIG_GLOBAL="$tmp/gitconfig"
# Under Git Bash, git is a Windows program: it reads C:/Users/..., and an include
# written as /c/Users/... is a file that does not exist. So the name and e-mail
# were lost and every commit in the suite failed (spec 020). cygpath exists only there.
winpath() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi; }
# The same for what reads a path inside a text rather than as an argument, which
# Git Bash converts on its own: Python source, a URL, a git config value.
rootw=$(winpath "$root")
fileurl() { local p; p=$(winpath "$1"); case "$p" in /*) printf 'file://%s' "$p" ;; *) printf 'file:///%s' "$p" ;; esac; }
# A PATH cut to the system's own folders keeps git: under Git Bash it is not in /usr/bin.
gitbin=$(dirname "$(command -v git)")
# Where a request goes that must leave nothing: a port nobody listens on. Windows
# answers a refused port on 127.0.0.1 after about two seconds and 0.0.0.0 at once,
# which kept the upstream checks there over a minute each (spec 020).
dead=http://127.0.0.1:9; if command -v cygpath >/dev/null 2>&1; then dead=http://0.0.0.0:9; fi
printf '[include]\n\tpath = %s\n\tpath = %s\n' "$(winpath "$HOME/.gitconfig")" "$(winpath "${XDG_CONFIG_HOME:-$HOME/.config}/git/config")" > "$GIT_CONFIG_GLOBAL"
# Nor this machine's builds (spec 015). A doctor run in a throwaway project with
# the Rust layer measures the build folder, and on a machine whose shell sets
# CARGO_TARGET_DIR that is every project's real one, hundreds of gigabytes. And
# a heavy recipe waits for a build already running, which on a machine where
# somebody is working is real: the suite would wait with them. The spec 015
# section sets each of these itself, with a fake ps.
unset CARGO_TARGET_DIR CARGO_BUILD_TARGET_DIR CARGO_BUILD_JOBS CARGO_PROFILE_DEV_DEBUG BUILD_OUTPUT_WARN_GB
export BUILD_WAIT_MINUTES=0
pass=0; fail=0
ok()    { pass=$((pass+1)); printf "  ok    %s\n" "$1"; }
bad()   { fail=$((fail+1)); printf "  FAIL  %s\n" "$1"; }
# A FAIL shows the last lines the check and its `says` saw: a red read from a CI
# log with nothing under it cost a guess on Windows (spec 020). Kept in files,
# not captured, because a check runs in this shell and may change its state.
check() {
  : > "$tmp/check.out"; : > "$tmp/says.out"
  if eval "$2" >"$tmp/check.out" 2>&1; then ok "$1"; else bad "$1"
    # A check that reads what an earlier command left in $out shows that instead.
    if [ -s "$tmp/check.out" ] || [ -s "$tmp/says.out" ]; then cat "$tmp/check.out" "$tmp/says.out"; else printf '%s\n' "${out:-}"; fi | tail -12 | sed 's/^/        /'
  fi
}
# What a command said — stdout and stderr together, matched as an extended
# regular expression:  says 'No GitHub address yet' just ci
#
# Never write `cmd | grep -q x` in this file. grep leaves the moment it matches,
# the command is still writing, and the SIGPIPE that kills it is a failure
# `set -o pipefail` hands back as the pipeline's: a FAIL that reruns differently
# and reproduces by hand not at all. It cost a day in 3.16.0. This captures
# first and looks afterwards, so there is no pipe left to race.
#
# The recipes run under /bin/bash 3.2 on every Mac and bash 5 on CI; a line that
# passes on one can fail on the other, so a check runs the line rather than
# reading it.
says() { local pat=$1; shift; local out; out=$( "$@" 2>&1 ); printf '%s\n' "$out" > "$tmp/says.out"; grep -qE -- "$pat" <<<"$out"; }
# `just doctor` reports the machine first and the repo second. A check about a
# project reads the repo half only: a laptop without `gh` on it is not a project
# with something missing, and failing the suite for it teaches nobody anything.
repo_doctor() { just doctor 2>&1 | sed -n '/^Repo:/,/^$/p'; }

echo "== the suite itself =="
# The guard for the line above: a pipe into grep anywhere here is the race back.
check "no check pipes a command into grep"            "! grep -E '^[^#]*\\| *grep' '$root/.ai-backbone/self-test.sh'"
# A recipe that takes a parameter reads it as $1 and never writes {{param}} into its
# script: text spliced into a script runs (3.20.0). The attribute sits on the line
# directly above the header. Prints every offence; empty when clean. The header is
# matched loosely on purpose — a quiet `@name arg:` and a default in single quotes
# were not seen at first — and `:=` keeps aliases and variables out. Seen working
# under both awks it meets: macOS awk 20200816, and mawk 1.3.4 20240123, which is
# `awk` in the scheduled agent's Linux sandbox (a one-off run there on 2026-09-19:
# nothing on the real recipes, every planted offence named). A parameter inside
# an expression, `{{ name + "" }}`, is the one shape it does not see; no recipe
# here has it, and a guard for a mistake nobody makes was not worth its regex.
spliced() {
  awk '
    /^@?[A-Za-z_][A-Za-z0-9_-]* +[+*$]?[A-Za-z_].*:/ && !/:=/ {
      name=$1; sub(/^@/, "", name); n=split($0, w, " "); np=0
      for (i=2; i<=n; i++) { p=w[i]; sub(/[=:].*/, "", p); sub(/^[+*$]+/, "", p); if (p ~ /^[A-Za-z_]/) params[++np]=p }
      if (prev !~ /positional-arguments/) print FILENAME ":" FNR ": " name " takes a parameter without [positional-arguments]"
      body=1; prev=$0; next }
    /^[^ \t]/ { body=0 }
    body { for (i=1; i<=np; i++) if ($0 ~ ("\\{\\{ *" params[i] " *\\}\\}")) print FILENAME ":" FNR ": " name " splices {{" params[i] "}}" }
    { prev=$0 }
  ' "$root/.ai-backbone/core.just" "$root/Justfile" "$root"/.ai-backbone/examples/stack-*.just
}
check "no recipe splices a parameter into its script"  "! says . spliced"
# The guard for the unset at the top: that very line, run under a hostile GIT_DIR,
# must leave none of git's variables behind (3.20.0).
git_vars_cleared() {
  local line; line=$(grep -m1 '^unset \$(git rev-parse --local-env-vars' "$root/.ai-backbone/self-test.sh") || return 1
  GIT_DIR="$tmp/not-here" GIT_INDEX_FILE="$tmp/not-here/index" GIT_WORK_TREE="$tmp" \
    bash -c "$line"'; [ -z "${GIT_DIR:-}${GIT_INDEX_FILE:-}${GIT_WORK_TREE:-}" ]'
}
check "the suite drops the git variables a hook hands it" "git_vars_cleared"
# One way to update a project, not two (3.20.0): the agent working in it, when its own
# session-start says it is behind. A daily `projects-update` wrote into projects from
# outside while somebody might be working there, and left one at "update FAILED".
# Only the recipe list is read: running projects.sh here would walk the real folders
# next to the real backbone.
check "nothing here updates a project from outside"   "! says 'projects-update' just -f '$root/Justfile' --summary"

echo "== setup.sh =="
# setup.sh asked uv once for each tool, and when a sandbox dropped that one request
# it ended by telling the reader to retype the command that had just failed, with a
# branch above it that could never be reached (3.20.0).
# Run with every tool faked, so nothing real is installed. `uname` says Linux so
# the uv branch runs on every machine; HOME is an empty folder and the PATH holds
# only the fakes and the system, so no real tool can shadow a fake; `uv` counts
# its `tool install` calls in a file, refuses the first UV_FAILS of them, then
# plants the tool in ~/.local/bin the way the real one does. The fake just
# answers --version, because the floor check below reads it.
f="$tmp/fakes"; mkdir -p "$f"
printf '#!/bin/sh\necho Linux\n' > "$f/uname"
for t in prek graphify gh; do printf '#!/bin/sh\necho "fake %s $*"\n' "$t" > "$f/$t"; done
printf '#!/bin/sh\ncase "$1" in --version) echo "just ${FAKE_JUST:-1.58.0}" ;; *) echo "fake just $*" ;; esac\n' > "$f/just"
cat > "$f/uv" <<'EOF'
#!/bin/sh
[ "$1 $2" = "tool install" ] || exit 0
n=$(( $(cat "$UV_COUNT" 2>/dev/null || echo 0) + 1 )); echo "$n" > "$UV_COUNT"
[ "$n" -le "$UV_FAILS" ] && { echo "error: fake uv refused (attempt $n)" >&2; exit 1; }
case "$3" in rust-just) b=just ;; graphifyy) b=graphify ;; *) b=$3 ;; esac
mkdir -p "$HOME/.local/bin"; printf '#!/bin/sh\ncase "$1" in --version) echo "just 1.58.0" ;; *) echo "fake %s $*" ;; esac\n' "$b" > "$HOME/.local/bin/$b"; chmod +x "$HOME/.local/bin/$b"
EOF
chmod +x "$f"/*
# Under dash where there is one: on a Mac `sh` is bash, and `dash -n` only parses, so a
# bash-only line in setup.sh stayed green here and went red on CI. And with a system
# folder of its own instead of /usr/bin: a machine with a packaged just there (Ubuntu
# 24.04, the case the floor was written for) found it when the check meant "no just".
# Each tool is a two-line script that runs the real one, not a link: under Git Bash
# `ln -s` copies, and a copied awk.exe cannot find the DLL beside the original (spec 020).
mkdir -p "$tmp/sys"; for t in git awk sort head cat mkdir chmod rm sed grep tr; do printf '#!/bin/sh\nexec "%s" "$@"\n' "$(command -v $t)" > "$tmp/sys/$t"; chmod +x "$tmp/sys/$t"; done
posix_sh=$(command -v dash || command -v sh)
setup() { rm -rf "$tmp/home" "$tmp/uv-count"; mkdir -p "$tmp/home"; HOME="$tmp/home" PATH="$f:$tmp/sys" UV_COUNT="$tmp/uv-count" UV_FAILS="$1" "$posix_sh" "$root/.ai-backbone/setup.sh" -y; }
calls() { cat "$tmp/uv-count" 2>/dev/null || echo 0; }
# The output is reused across checks, so `says` is not used here; the herestrings
# read a variable, not a pipe.
check "setup.sh parses under dash where there is one"  "! command -v dash >/dev/null || dash -n '$root/.ai-backbone/setup.sh'"
out=$(setup 0 2>&1); rc=$?
check "with every tool present, setup.sh installs nothing and ends in doctor" "[ \$(calls) = 0 ] && ! grep -q '^-> ' <<<\"\$out\" && grep -q 'fake just doctor' <<<\"\$out\""
# One meaning for the exit code (3.21.1): it answers "are the tools here", and
# nothing else. It used to be 0 when just could not be installed at all and 1
# when it was merely too old, so a caller reading it got the opposite answer for
# the worse case. The repo's own state — no vault, no hooks — stays doctor's.
check "and says so with 0"                            "[ \$rc -eq 0 ]"
rm -f "$f/just"
out=$(setup 1 2>&1)
check "a tool uv refuses once is asked for once more"  "[ \$(calls) = 2 ] && grep -q 'fake just doctor' <<<\"\$out\""
out=$(setup 9 2>&1); rc=$?
check "refused twice: no third try, and both answers are shown" "[ \$(calls) = 2 ] && grep -q 'refused (attempt 1)' <<<\"\$out\" && grep -q 'refused (attempt 2)' <<<\"\$out\""
check "and the ending points at them instead of a command to retype" "grep -q 'is not on the PATH' <<<\"\$out\" && ! grep -q 'Install it by hand' <<<\"\$out\""
check "and a tool that never arrived ends the script at 1, named"  "[ \$rc -ne 0 ] && grep -q 'Still missing: just' <<<\"\$out\""
# The floor: a just older than 1.29.0 cannot parse core.just, so setup.sh is the one
# place that can say so, and it moves the just itself (3.20.0).
check "setup.sh's version compare orders like a person would"  "sh -c \"\$(sed -n '/^ver_ge()/p' '$root/.ai-backbone/setup.sh'); ver_ge 1.58.0 1.29.0 && ver_ge 1.29.0 1.29.0 && ! ver_ge 1.21.0 1.29.0 && ! ver_ge 1.9.0 1.29.0\""
# (`check` evals in this shell, so the variable is not called f: that is the fakes' folder.)
check "the just floor in setup.sh is the one core.just names" "floor=\$(sed -n 's/^need_just=//p' '$root/.ai-backbone/setup.sh'); [ -n \"\$floor\" ] && [ \"\$floor\" = \"\$(grep -m1 -oE 'Needs just [0-9.]+' '$root/.ai-backbone/core.just' | awk '{print \$3}')\" ]"
printf '#!/bin/sh\ncase "$1" in --version) echo "just 1.20.0" ;; *) echo "fake just $*" ;; esac\n' > "$f/just"; chmod +x "$f/just"
out=$(setup 0 2>&1)
check "setup.sh moves a just that is too old, and says which one" "grep -q 'just 1.20.0 at .* is older than 1.29.0' <<<\"\$out\" && [ \$(calls) = 1 ] && grep -q 'fake just doctor' <<<\"\$out\""
out=$(setup 1 2>&1)
check "a move uv refuses once is asked for once more, like every other install" "[ \$(calls) = 2 ] && grep -q 'fake just doctor' <<<\"\$out\""
out=$(setup 9 2>&1); rc=$?
check "and stops, naming the version and the path, when it cannot" "[ \$rc -ne 0 ] && [ \$(calls) = 2 ] && grep -q 'still 1.20.0 at' <<<\"\$out\" && ! grep -q 'fake just doctor' <<<\"\$out\" && ! grep -q 'Linux:  uv tool install' <<<\"\$out\""
rm -f "$f/just"
# tools-update on a Linux box: just came through uv and brew is not there. The PATH
# hides brew and prek, or the suite would upgrade this machine's tools on every core commit.
mkdir -p "$tmp/shim"; ln -sf "$(command -v just)" "$tmp/shim/just"
printf '#!/bin/sh\ncase "$1 $2" in "tool list") cat "$UV_FAKE_LIST" ;; "tool upgrade") echo "Upgraded $3" ;; esac\n' > "$tmp/shim/uv"; chmod +x "$tmp/shim/uv"
printf 'rust-just v1.58.0\n- just\n' > "$tmp/list-linux"; printf 'prek v0.5.3\n- prek\n' > "$tmp/list-mac"
check "tools-update moves a just that uv installed"   "says 'Upgraded rust-just' env UV_FAKE_LIST='$tmp/list-linux' PATH='$tmp/shim:/usr/bin:/bin' just -f '$root/Justfile' -d '$tmp/home' tools-update"
check "and leaves a brew just alone"                  "! says 'rust-just' env UV_FAKE_LIST='$tmp/list-mac' PATH='$tmp/shim:/usr/bin:/bin' just -f '$root/Justfile' -d '$tmp/home' tools-update"

echo "== a new project =="
# On a failure the output is shown: everything below builds on this project, and
# a red here read from a CI log with nothing under it cost a guess (spec 020).
if np_out=$( cd "$root" && just new-project "$tmp/Deneme Projesi" tr 2>&1 ); then ok "new-project runs"; else bad "new-project runs"; printf '%s\n' "$np_out" | tail -20 | sed 's/^/        /'; fi
p="$tmp/deneme-projesi"
check "folder name is a slug"                         "[ -d '$p' ]"
cd "$p" || exit 1
# Sorted in the C locale: a Mac runner's ls put `brain` before `CLAUDE.md`
# (measured 2026-09-24), and the order was never the point.
visible=$(ls -1 | LC_ALL=C sort | tr '\n' ' ')
# The FAIL names what was seen: on a runner nobody can type ls there.
check "visible items: AGENTS CLAUDE GEMINI Justfile LICENSE README brain docs src (saw: $visible)" "[ '$visible' = 'AGENTS.md CLAUDE.md GEMINI.md Justfile LICENSE README.md brain docs src ' ]"
n=$(git ls-files | wc -l | tr -d ' ')
# A new project stays small enough to read in one sitting. The number is a
# ceiling somebody has to decide to raise, not a limit: 40 since 3.12.0, when
# every project gained the upstream watch and the routine.
# 42 since 3.24.0: budget.py and agent-cap.sh reach every project (spec 014), the
# maintainer's decision of 2026-09-22 in an attended session. Still a ceiling
# somebody has to decide to raise, never a scheduled run.
# 43 since 3.27.5: .gitattributes, so a project checks out with LF on Windows
# (spec 020, which the maintainer approved on 2026-09-24 in an attended session).
check "tracked files at most 43 (got $n)"             "[ $n -le 43 ]"
# Two more ceilings, set at what a new project measured on 2026-09-19 (spec 012).
# An agent nobody watches works on this backbone every day and builds ideas it
# read about; every one of them is small and sensible, and a hundred of them are
# not the radically simple thing a non-programmer was promised. A red check is
# a brake an agent respects and a sentence is not: at the ceiling, adding means
# taking something out first. Raising a number is a person's decision, made in
# an attended session; the scheduled agent's stored prompt forbids it.
# 38 since 3.25.0: `just stale` (spec 015), which the maintainer approved with
# the rest of that spec on 2026-09-23 in an attended session. 39 since 3.26.0:
# `just release` (spec 016), the project's own version, which the maintainer
# asked for and chose the timing of in an attended session the same day.
r=$(just --summary 2>/dev/null | wc -w | tr -d ' ')
check "recipes a new project shows at most 39 (got $r)" "[ $r -le 39 ]"
b=$(wc -c < AGENTS.md | tr -d ' ')
check "AGENTS.md at most 7000 bytes (got $b)"         "[ $b -le 7000 ]"
# spec 013, docs: sentences an agent acts on, held where the agent reads them: in
# the new project for what a project carries, in the backbone ($root) for what
# lives only there. A sentence is not behaviour, so each check asks for the few
# words that carry the rule. Every one of them failed on 3.21.3, but for the one
# about the scanner's version, which says what it failed on.
# Section 4: graphify 0.9.64 draws no calls in Dart, and "affected" found none of
# two real callers there, so the rule names both ways to ask who uses a thing.
# Section 7: an agent once put the owner's e-mail into the User-Agent of three
# API calls, because the service asked for a contact.
check "AGENTS.md names just uses beside graphify affected" "grep -q 'graphify affected' AGENTS.md && grep -q 'just uses <word>' AGENTS.md"
check "AGENTS.md keeps the maintainer's name out of a third party's hands" "grep -q 'name or e-mail to a third-party service' AGENTS.md && grep -q 'User-Agent' AGENTS.md"
# The public standards reach a project through a skill, because an update carries
# a skill and never the seed AGENTS.md. The kinds are read from the save recipe:
# a kind added there and not in the skill is a red check, not a stale sentence.
std=.agents/skills/session/SKILL.md
check "the session skill names three public standards by their address" "grep -q 'https://semver.org' $std && grep -q 'https://keepachangelog.com' $std && grep -q 'https://www.conventionalcommits.org' $std && grep -q 'first version is 0\\.1\\.0' $std"
kinds_named() {
  local k n=0
  for k in $(grep -m1 -oE '\^\(feat[a-z|]*\)' "$root/.ai-backbone/core.just" | tr -d '^()' | tr '|' ' '); do
    grep -qF "\`$k\`" "$std" || return 1; n=$((n+1))
  done
  [ "$n" -ge 5 ]
}
check "and every kind of commit message that save accepts" "kinds_named"
check "the spec skill asks for a question that carries its answer" "grep -q 'the answer you would give' .agents/skills/spec/SKILL.md && grep -q 'each with the answer you' .ai-backbone/templates/spec.md"
check "the ADR template takes no 'from memory' after Nothing" "grep -q 'is never the reason' .ai-backbone/templates/adr.md"
# The project brief learned what the backbone's own learned in 3.21.0: a pasted
# brief is a second truth, a checkout with no branch refuses `git push origin
# HEAD` (measured on git 2.55.0: "not a full refname"), and a push GitHub refuses
# because it moved has an answer. The pointer it offers a scheduler rests on
# `routine.sh --brief` naming a file that begins "# Routine", so that is run.
check "the project brief is pointed at, never pasted"  "brief13=\$(sh .ai-backbone/routine.sh --brief) && case \"\$(head -1 \"\$brief13\")\" in '# Routine'*) grep -q 'routine.sh --brief' \"\$brief13\" && ! grep -qi 'paste it as the prompt' \"\$brief13\" ;; *) false ;; esac"
check "and says what to do with no branch, and with a push GitHub refuses" "grep -q 'git push origin HEAD:<branch>' .ai-backbone/templates/routine-project.md && grep -q 'git pull --rebase origin <branch>' .ai-backbone/templates/routine-project.md && grep -q 'git rebase --abort' .ai-backbone/templates/routine-project.md"
check "the walkthrough sends an edit of the brief to a copy no update overwrites" "grep -q 'edit the copy' '$root/docs/01-getting-started.md' && ! grep -q 'by editing the brief it reads' '$root/docs/01-getting-started.md'"
# just on Linux is rust-just from PyPI, a third party's repackaging, and until
# now no tracked file said so. The header ends where the script begins (set -u).
sed -n '1,/^set -u/p' .ai-backbone/setup.sh > "$tmp/setup-header"
check "setup.sh's header and the walkthrough say where just comes from on Linux" "grep -q 'rust-just' '$tmp/setup-header' && grep -q 'pypi:' '$tmp/setup-header' && grep -q 'rust-just' '$root/docs/01-getting-started.md'"
# Two limits were accepted on purpose and a close reading kept finding them as
# bugs: Turkish typed in plain ASCII passes the commit-message check, and the
# scanner lets Amazon's documented EXAMPLE key through. Each is written where the
# check lives. The comment in the hook config must not carry the scanner's
# version: upstream.py looks for the pin anywhere in that file, and the first
# draft of the comment, which named it twice, would have hidden a moved pin.
check "the two limits accepted on purpose are written where the checks live" "grep -q 'A limit accepted on purpose' '$root/.ai-backbone/core.just' && grep -q 'A limit accepted on purpose' '$root/.pre-commit-config.yaml'"
hookrev=$(awk '/gitleaks\/gitleaks/ {f=1; next} f && /rev:/ {print $2; exit}' "$root/.pre-commit-config.yaml")
check "the hook config holds its scanner's version once, on the rev line ($hookrev)" "[ -n '$hookrev' ] && [ \"\$(grep -cF -- '$hookrev' '$root/.pre-commit-config.yaml')\" = 1 ]"
# docs/how-it-works.md: two pictures GitHub draws from text, for a person who
# does not read code. What can be held without a browser: two mermaid blocks,
# both plain flowcharts, every label in quotes, nothing GitHub refuses (click
# handlers, themes, HTML), and few enough boxes to follow: 14 and 8. Those two
# numbers are ceilings like the three above, and they are raised the same way.
hiw="$root/docs/how-it-works.md"
awk '/^```mermaid/ {n++; inside=1; next} /^```/ {inside=0; next} inside {print n ": " $0}' "$hiw" > "$tmp/hiw.mmd" 2>/dev/null
hiw_boxes() { grep -cE "^$1: +[a-z0-9]+[[(]+\"" "$tmp/hiw.mmd"; }
b1=$(hiw_boxes 1); b2=$(hiw_boxes 2)
check "how-it-works holds two pictures GitHub can draw" "[ \"\$(grep -cE '^[12]: flowchart (TD|LR)\$' '$tmp/hiw.mmd')\" = 2 ] && ! grep -q '^3: ' '$tmp/hiw.mmd' && ! grep -qE '^[12]: +(click|style|classDef|linkStyle) |%%\\{|<[a-z]' '$tmp/hiw.mmd' && ! grep -qE '^[12]: +[a-z0-9]+[[(]+[^\"[(]' '$tmp/hiw.mmd'"
check "and both stay small enough to follow: 14 and 8 boxes (got ${b1:-0} and ${b2:-0})" "[ ${b1:-0} -ge 2 ] && [ ${b1:-0} -le 14 ] && [ ${b2:-0} -ge 2 ] && [ ${b2:-0} -le 8 ]"
check "README and docs/README lead to it"              "grep -q 'docs/how-it-works.md' '$root/README.md' && grep -q 'how-it-works.md' '$root/docs/README.md'"
# 3.22.0 gave the scheduled agent a Sunday of its own and left the pages that
# describe that agent as they were. The picture above draws the radar, so the
# words beside it must exist too.
check "the docs say what the scheduled agent does on a Sunday" "grep -q 'radar.toml' '$root/docs/01-getting-started.md' && grep -q 'radar.toml' '$root/docs/README.md'"
check "project name kept as typed"                    "grep -q '^| project | Deneme Projesi |' AGENTS.md"
check "brain_lang and chat_lang set from the argument" "grep -q '^| brain_lang | tr |' AGENTS.md && grep -q '^| chat_lang | tr |' AGENTS.md"
check "no .env.example before the first secret"       "[ ! -f .env.example ]"
# Every project gets upstream.py and radar.py, so every project can grow a
# __pycache__/. One was staged by the scheduled run of 2026-09-22, and a tracked
# .pyc makes `git status` dirty in every fresh checkout, which is where the
# routine brief stops (3.23.2).
mkdir -p .ai-backbone/__pycache__ && : > .ai-backbone/__pycache__/upstream.cpython-311.pyc
# An agent is shown a SessionStart hook's output whole only up to 10,000
# characters; past that it sees the first 2,000 of a file (Claude Code 2.1.273).
# The journal alone reached 17,000 in one project, so agents began every session
# with the head of a diary and nothing else. What matters comes first now, every
# block is bounded, and the whole is cut at 9,500 and says so (3.23.3).
mkdir -p brain/01-journal docs/specs && python3 -c "print('---\nlang: tr\n---\n# Uzun bir gün\n' + ('- yapıldı: bir şey daha\n' * 900))" > brain/01-journal/2026-01-01.md
out=$(just session-start 2>&1)
check "a session start with a huge journal stays under what an agent is shown" "[ \${#out} -le 10000 ] && grep -q '^=== WORKING TREE' <<<\"\$out\" && grep -q 'the rest is in brain/01-journal/2026-01-01.md' <<<\"\$out\""
check "and the working tree comes before the journal"    "[ \$(grep -n '=== WORKING TREE' <<<\"\$out\" | cut -d: -f1) -lt \$(grep -n '=== LAST JOURNAL' <<<\"\$out\" | cut -d: -f1) ]"
for i in $(seq 1 80); do printf -- '---\nstatus: approved\n---\n# %03d\n## Tasks\n- [ ] %s\n' "$i" "$(printf 'a very long first task that runs on and on %.0s' $(seq 1 12))" > "docs/specs/$(printf '%03d' "$i")-x.md"; done
out=$(just session-start 2>&1)
check "and whatever it grows to, the whole is cut at 9,500 and says so" "[ \${#out} -le 10000 ] && grep -q '^(cut at 9,500 characters' <<<\"\$out\""
rm -f docs/specs/0[0-9][0-9]-x.md brain/01-journal/2026-01-01.md
# What the week can take (spec 014). A fixture stands in for the transcripts and
# for Claude Code's meter, so the real ones are never read or written by a test.
echo "== the budget =="
bt="$tmp/budget"; mkdir -p "$bt/projects/p1/s1/subagents" "$bt/home"
py=$(just _py); nowz=$(date -u +%Y-%m-%dT%H:%M:%S.000Z)
msg() { printf '{"type":"assistant","timestamp":"%s","message":{"id":"%s","model":"claude-opus-5","usage":{"input_tokens":%s,"cache_creation_input_tokens":0,"cache_read_input_tokens":%s,"output_tokens":%s}}}\n' "$nowz" "$1" "$2" "$3" "$4"; }
{ msg m1 10 1000 5; msg m1 10 1000 40; msg m2 20 2000 7; printf '{"type":"assistant","timestamp":"%s","message":{"id":"m3","model":"<synthetic>","usage":{}},"quotaLimits":{"rateLimitType":"seven_day","resetsAt":%s}}\n' "$nowz" "$(( $(date +%s) + 86400 * 3 ))"; msg m1 10 1000 40; } > "$bt/projects/p1/s1.jsonl"
msg a1 5 500 3 > "$bt/projects/p1/s1/subagents/agent-x.jsonl"
# Three days to the reset with 46% used is behind the pace, so the cap stands at
# its setting; six days would be ahead of it and halve the cap, which is its own
# check below.
resets=$(( $(date +%s) + 86400 * 3 )); fresets=$(( $(date +%s) + 3600 ))
ms=$(( $(date +%s) * 1000 - 16 * 60000 ))
"$py" - "$bt/home/meter.json" "$ms" "$resets" "$fresets" <<'PYEOF'
import json,sys,datetime
iso=lambda t: datetime.datetime.fromtimestamp(int(t),datetime.timezone.utc).isoformat()
json.dump({"cachedUsageUtilization":{"fetchedAtMs":int(sys.argv[2]),"utilization":{"seven_day":{"utilization":46,"resets_at":iso(sys.argv[3])},"five_hour":{"utilization":10,"resets_at":iso(sys.argv[4])}}}},open(sys.argv[1],"w"))
PYEOF
bud() { env AI_BACKBONE_BUDGET_PROJECTS="$bt/projects" AI_BACKBONE_BUDGET_METER="$bt/home/meter.json" AI_BACKBONE_BUDGET_CACHE="$bt/cache.json" GIT_CONFIG_GLOBAL="$bt/gitconfig" "$py" "$root/.ai-backbone/budget.py" "$@"; }
: > "$bt/gitconfig"
check "a message counts once whatever its blocks and repeats, a subagent's once more" "says '\"msgs\": 3' bud --json && says '\"output\": 50' bud --json && says '\"cache_read\": 3500' bud --json"
check "the line says the meter's percent and its age, the days, and the cap" "says 'Omurgadan not: haftalık kullanım yaklaşık %46 .ölçer 1[5-9] dk önce., 5 saatlik pencere %10' bud --line tr && says 'sormadan 8 alt ajana kadar' bud --line tr && says '3 gün .[0-9] iş günü' bud --line tr && says '/usage' bud --line tr"
git config --file "$bt/gitconfig" ai-backbone.weekend work; git config --file "$bt/gitconfig" ai-backbone.agent-cap 3
check "the person's two settings change the days and the cap" "says '3 gün kaldı' bud --line tr && ! says 'iş günü' bud --line tr && says 'sormadan 3 alt ajana' bud --line tr"
check "and English is English"                          "says 'Backbone note: about 46% of the week' bud --line en && says 'up to 3 subagents without asking' bud --line en"
"$py" - "$bt/home/meter.json" "$(( $(date +%s) + 86400 * 6 ))" <<'PYEOF'
import json,sys,datetime; d=json.load(open(sys.argv[1])); d["cachedUsageUtilization"]["utilization"]["seven_day"]["resets_at"]=datetime.datetime.fromtimestamp(int(sys.argv[2]),datetime.timezone.utc).isoformat(); json.dump(d,open(sys.argv[1],"w"))
PYEOF
git config --file "$bt/gitconfig" ai-backbone.weekend rest; git config --file "$bt/gitconfig" --unset ai-backbone.agent-cap
check "ahead of the week's pace, the cap is halved"      "says 'sormadan en fazla 4 alt ajana' bud --line tr"
"$py" - "$bt/home/meter.json" <<'PYEOF'
import json,sys; d=json.load(open(sys.argv[1])); d["cachedUsageUtilization"]["utilization"]["seven_day"]["utilization"]=91; json.dump(d,open(sys.argv[1],"w"))
PYEOF
check "past 80 percent the tone changes and the cap drops to one" "says '^Dikkat: haftalık kullanım yaklaşık %91' bud --line tr && says 'en fazla 1 alt ajan' bud --line tr"
"$py" - "$bt/home/meter.json" "$(( $(date +%s) - 3600 ))" <<'PYEOF'
import json,sys,datetime; d=json.load(open(sys.argv[1])); d["cachedUsageUtilization"]["utilization"]["seven_day"]["resets_at"]=datetime.datetime.fromtimestamp(int(sys.argv[2]),datetime.timezone.utc).isoformat(); json.dump(d,open(sys.argv[1],"w"))
PYEOF
check "a meter read before the reset is not this week's: the line says the week is new and unknown" "says '^Yeni hafta: ölçer sıfırlanmadan önce okunmuş' bud --line tr && ! says '%91' bud --line tr && says 'en fazla 8 alt ajan' bud --line tr && says 'New week: the meter was read before the reset' bud --line en"
"$py" - "$bt/home/meter.json" "$(( $(date +%s) + 40000 ))" <<'PYEOF'
import json,sys,datetime; d=json.load(open(sys.argv[1])); d["cachedUsageUtilization"]["utilization"]["seven_day"]["resets_at"]=datetime.datetime.fromtimestamp(int(sys.argv[2]),datetime.timezone.utc).isoformat(); d["cachedUsageUtilization"]["utilization"]["seven_day"]["utilization"]=46; json.dump(d,open(sys.argv[1],"w"))
PYEOF
check "less than a working day left never prints a share above what is left" "! says 'günlük pay yaklaşık %[0-9][0-9][0-9]' bud --line tr && says 'günlük pay yaklaşık %54' bud --line tr"
check "the day's number the line says is written where the hook reads it" "bud --line tr >/dev/null && [ \"\$(cat '$tmp/T/ai-backbone-agents/today-cap')\" = 8 ]"
chmod 555 "$bt"; ro="$bt/ro-cache.json"
check "an unwritable cache leaves the line one line"   "[ \$(env AI_BACKBONE_BUDGET_PROJECTS='$bt/projects' AI_BACKBONE_BUDGET_METER='$bt/home/meter.json' AI_BACKBONE_BUDGET_CACHE='$ro' GIT_CONFIG_GLOBAL='$bt/gitconfig' '$py' '$root/.ai-backbone/budget.py' --line tr 2>/dev/null | wc -l | tr -d ' ') -eq 1 ]"
chmod 755 "$bt"
check "without a meter the line says so, quietly, and the cap holds" "says 'kullanım ölçeri bu makinede henüz yok' env AI_BACKBONE_BUDGET_METER='$bt/nowhere.json' AI_BACKBONE_BUDGET_PROJECTS='$bt/projects' AI_BACKBONE_BUDGET_CACHE='$bt/c2.json' GIT_CONFIG_GLOBAL='$bt/gitconfig' '$py' '$root/.ai-backbone/budget.py' --line tr"
check "the line is the first thing a session says"     "[ \"\$(env AI_BACKBONE_BUDGET_PROJECTS='$bt/projects' AI_BACKBONE_BUDGET_METER='$bt/home/meter.json' AI_BACKBONE_BUDGET_CACHE='$bt/c3.json' GIT_CONFIG_GLOBAL='$bt/gitconfig' just session-start 2>/dev/null | head -1 | cut -c1-9)\" = 'Omurgadan' ]"
check "the cache stays outside the transcripts and the meter is untouched" "[ -f '$bt/cache.json' ] && [ ! -e '$bt/projects/cache.json' ] && grep -q '\"utilization\": 46' '$bt/home/meter.json'"
# The hook: fixture stdin, a scratch TMPDIR, a scratch global config. Eight allowed,
# the ninth refused with the count and the cap; a workflow gated until the yes;
# the yes lifts it for the session and a bad id neither counts nor blocks.
hk="$tmp/hook"; mkdir -p "$hk"; hcall() { printf '{"session_id":"%s","tool_name":"%s","tool_use_id":"%s","tool_input":{}}' "$1" "$2" "$3" | env TMPDIR="$hk" GIT_CONFIG_GLOBAL="$bt/gitconfig" AI_BACKBONE_AGENT_CAP= bash "$root/.ai-backbone/agent-cap.sh"; }
git config --file "$bt/gitconfig" --unset ai-backbone.agent-cap
allowed=0; for i in 1 2 3 4 5 6 7 8; do [ -z "$(hcall s9 Agent t$i)" ] && allowed=$((allowed+1)); done
check "eight subagents start without a word"           "[ $allowed -eq 8 ]"
check "the ninth is refused, with the count, the cap and the ask" "says '\"deny\"' hcall s9 Agent t9 && says '8 subagents already started this session and the cap is 8' hcall s9 Agent t9 && says 'ask the person' hcall s9 Agent t9 && says 'just _agent-cap' hcall s9 Agent t9"
check "a workflow is gated until the person's yes"      "says 'a workflow starts many subagents on its own' hcall s9 Workflow w1 && says '\"deny\"' hcall s2 Workflow w2"
check "the yes lifts the cap for that session only"     "just _agent-cap 12 '$hk/ai-backbone-agents/s9' >/dev/null && [ -z \"\$(hcall s9 Agent t10)\" ] && [ -z \"\$(hcall s9 Workflow w3)\" ] && says '\"deny\"' hcall s9 Workflow w4 || true; [ -f '$hk/ai-backbone-agents/s9/cap' ]"
check "a refused call is not counted"                    "[ \$(wc -l < '$hk/ai-backbone-agents/s9/started' | tr -d ' ') -eq 9 ]"
check "no usable session id: neither counted nor blocked" "[ -z \"\$(printf '{\"tool_name\":\"Agent\"}' | env TMPDIR='$hk' bash '$root/.ai-backbone/agent-cap.sh')\" ]"
check "_agent-cap refuses what is not a number or not a session folder" "! just _agent-cap x '$hk/ai-backbone-agents/s9' && ! just _agent-cap 5 '$hk/elsewhere'"
# The hook into a project's settings, merged, once, and out again.
sj="$tmp/hook/settings.json"; cp "$root/.claude/settings.json" "$sj"
check "the hook is removed and added back without touching the rest" "[ \"\$('$py' '$root/.ai-backbone/budget.py' hook remove '$sj')\" = removed ] && ! grep -q agent-cap '$sj' && grep -q 'session-start' '$sj' && [ \"\$('$py' '$root/.ai-backbone/budget.py' hook add '$sj')\" = added ] && [ \"\$('$py' '$root/.ai-backbone/budget.py' hook add '$sj')\" = 'already there' ] && '$py' '$root/.ai-backbone/budget.py' hook check '$sj' && cmp -s '$sj' '$root/.claude/settings.json'"
"$py" - "$tmp/hook/two.json" <<'PYEOF'
import json,sys; g=lambda m:{"matcher":m,"hooks":[{"type":"command","command":'bash "$CLAUDE_PROJECT_DIR"/.ai-backbone/agent-cap.sh'}]}; json.dump({"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"true"}]},g("Agent"),g("Agent|Workflow")]}},open(sys.argv[1],"w"))
PYEOF
check "two copies of the hook become one, beside a stranger's group" "[ \"\$('$py' '$root/.ai-backbone/budget.py' hook add '$tmp/hook/two.json')\" = updated ] && '$py' -c \"import json,sys;g=json.load(open(sys.argv[1]))['hooks']['PreToolUse'];assert [x['matcher'] for x in g]==['Bash','Agent|Workflow'],g\" '$tmp/hook/two.json'"
printf '{ // a comment\n  "hooks": {} }\n' > "$tmp/hook/jsonc.json"
check "a settings file that is not plain JSON is left alone and said" "! '$py' '$root/.ai-backbone/budget.py' hook add '$tmp/hook/jsonc.json' 2>/dev/null && grep -q '// a comment' '$tmp/hook/jsonc.json'"
check "the same call counted once, however many times the hook sees it" "hcall s9 Agent t10 >/dev/null; hcall s9 Agent t10 >/dev/null; [ \$(grep -c '^t10\$' '$hk/ai-backbone-agents/s9/started') -eq 1 ]"
# Twelve at once, the shape of an audit's lenses: eight pass, four are refused.
for i in $(seq 1 12); do ( hcall s12 Agent p$i > "$hk/p$i.out" 2>&1 ) & done; wait
check "twelve agents started in one breath: eight pass and four are refused" "[ \$(grep -l deny '$hk'/p*.out | wc -l | tr -d ' ') -eq 4 ] && [ \$(wc -l < '$hk/ai-backbone-agents/s12/started' | tr -d ' ') -eq 8 ]"
echo 4 > "$hk/ai-backbone-agents/today-cap"
for i in 1 2 3 4; do hcall s13 Agent q$i >/dev/null; done
check "the day's number holds in the hook, under the machine's setting" "says 'the cap is 4' hcall s13 Agent q5"
rm -f "$hk/ai-backbone-agents/today-cap"
check "a project with no settings file gets one with only the hook" "[ \"\$('$py' '$root/.ai-backbone/budget.py' hook add '$tmp/hook/none/.claude/settings.json')\" = added ] && '$py' -c \"import json,sys;d=json.load(open(sys.argv[1]));assert list(d)==['hooks']\" '$tmp/hook/none/.claude/settings.json'"
check "hooks-install says when it put the hook in"      "'$py' '$root/.ai-backbone/budget.py' hook remove .claude/settings.json >/dev/null && says 'Subagent cap: in .claude/settings.json, added' just hooks-install"
check "and so does template-update, for a project made before the hook existed" "'$py' '$root/.ai-backbone/budget.py' hook remove .claude/settings.json >/dev/null && says 'Subagent cap: in .claude/settings.json, added' just template-update && '$py' '$root/.ai-backbone/budget.py' hook check .claude/settings.json"
"$py" "$root/.ai-backbone/budget.py" hook add .claude/settings.json >/dev/null 2>&1 || true   # whatever the check found, the project keeps its hook
check "the seed gives a new project the hook"           "grep -q 'agent-cap.sh' '$root/.claude/settings.json'"
# Claude Code's skills are copies, never links: Git for Windows checks a link out
# as a text file naming its target, and Claude Code found no skills (spec 020).
check "a new project's skills are copies Claude Code reads on any machine" "[ -f .claude/skills/session/SKILL.md ] && [ ! -L .claude/skills/session ] && just _rules-check"
echo 'an edit' >> .claude/skills/spec/SKILL.md
check "a skill copy that differs from its source is named"  "says 'claude/skills/spec is out of date' just _rules-check"
rm -rf .claude/skills/spec; ln -s ../../.agents/skills/spec .claude/skills/spec
cp .agents/skills/spec/SKILL.md "$tmp/spec-skill-before"
check "sync-rules turns an older project's link into a copy, and writes nothing through it" "just sync-rules >/dev/null && [ ! -L .claude/skills/spec ] && diff -r .agents/skills/spec .claude/skills/spec && cmp -s .agents/skills/spec/SKILL.md '$tmp/spec-skill-before' && just _rules-check"

check "what python leaves behind is never saved"      "[ -z \"\$(git status --porcelain --untracked-files=all -- .ai-backbone/__pycache__)\" ] && git check-ignore -q .ai-backbone/__pycache__/upstream.cpython-311.pyc"
check "LICENSE names the maker, not the backbone"     "! grep -q 'yerly.tech' LICENSE"
check "both git hooks installed"                      "[ -f .git/hooks/pre-commit ] && [ -f .git/hooks/commit-msg ]"
check "plain just shows the save command"             "says 'just save' just"
check "save on a clean tree is calm"                  "says 'Nothing new to save|yeni bir şey yok' just save x"
check "spec name becomes a slug"                      "just spec 'İlk Fikir' && [ -f docs/specs/001-ilk-fikir.md ]"
check "plain save message gets chore:"                "just save 'first spec' && says '^chore: first spec' git log -1 --format=%s"
# Free text reaches a recipe's script as an argument, never as text spliced into it
# (3.20.0): a dollar sign stays a dollar sign, a dollar-paren runs nothing, quotes and
# backticks arrive as typed. The file that must not exist is the important check.
echo x >> src/README.md
check "save keeps a dollar sign in the message"        "just save 'fix: pay \$amount' && says '^fix: pay \\\$amount\$' git log -1 --format=%s"
echo x >> src/README.md
check "save runs nothing a message asks it to"         "just save 'fix: \$(touch $tmp/PWNED)' && [ ! -e '$tmp/PWNED' ] && says '^fix: \\\$\\(touch ' git log -1 --format=%s"
echo x >> src/README.md
check "save keeps quotes and backticks as typed"       "just save 'fix: say \"hi\" and run \`ls\`' && [ \"\$(git log -1 --format=%s)\" = 'fix: say \"hi\" and run \`ls\`' ]"
echo x >> src/README.md
check "yedekle passes the message through untouched"   "just yedekle 'fix: pay \$amount again' && says '^fix: pay \\\$amount again\$' git log -1 --format=%s"
check "spec name with a dollar sign becomes a slug"    "just spec 'Pay \$amount' && compgen -G 'docs/specs/*-pay-amount.md' && grep -q '— Pay \\\$amount\$' docs/specs/*-pay-amount.md"
# A project's name goes into AGENTS.md through perl. Pasted into the substitution it
# was perl code, and a name could run a command (3.20.0); now perl reads it from the
# environment and the name is kept as typed.
check "new-project runs nothing a name asks it to"     "( cd '$root' && just new-project '$tmp/Ad @{[system q(touch PWNED3)]}' ) && [ ! -e '$tmp/ad-system-q-touch-pwned3/PWNED3' ] && grep -qF '| project | Ad @{[system q(touch PWNED3)]} |' '$tmp/ad-system-q-touch-pwned3/AGENTS.md'"
echo x >> src/README.md
check "Turkish commit message is rejected"            "! just save 'özellik: deneme'"
git reset -q --hard
check "template-check says up to date"                "says 'up to date' just template-check"
check "doctor finds nothing missing in the repo"      "! says '^  (MISS|warn)' repo_doctor"
check "a new project is not told to map code it has not written yet" "! says 'no code map' repo_doctor"
# spec 013, codemap: what a Flutter game found in its first week, about the code
# map first and the seed files after it. Its runner shims are Swift and Kotlin,
# which is the only reason it was ever told it had code.
mkdir -p src/lib && printf 'class SwapGame {}\nclass SwapGameBoard {}\n' > src/lib/game.dart
check "a project with nothing but Dart in it has code to map" "[ \"\$(just _has-code)\" = yes ] && says 'no code map' repo_doctor"
# graphify itself is a fake from here on: a sandbox may not have it, and what is
# checked is what update-map asks of it and what it does to the project's
# ignore file. What graphify 0.9.64 does with the answer was measured by hand,
# and the numbers are in the recipe.
fm="$tmp/fake-map"; mkdir -p "$fm"
printf '#!/bin/sh\necho "$*" >> "%s/calls"\ncase "$1" in extract|update) mkdir -p graphify-out; echo "{}" > graphify-out/graph.json ;; esac\n' "$fm" > "$fm/graphify"; chmod +x "$fm/graphify"
map() { PATH="$fm:$PATH" just update-map; }
check "the first map leaves out the backbone's own folder and the documents" "map && grep -qxF '.ai-backbone/' .graphifyignore && grep -qxF '*.md' .graphifyignore"
# The ignore file is the project's after the first run, so a project older than
# a line never got it. Lines are added at the end, never taken out or moved, a
# line somebody commented out counts as answered, and a file that ends without
# a newline (hand-edited ones do) does not get its last line glued to the first
# new one.
printf 'brain/\nmy-own/\n# *.md' > .graphifyignore
map >/dev/null 2>&1; map >/dev/null 2>&1
check "an older ignore file gains what it lacks, once, and keeps its own lines and its refusals" "[ \"\$(sed -n 1p .graphifyignore)\" = brain/ ] && grep -qxF 'my-own/' .graphifyignore && grep -qxF '# *.md' .graphifyignore && [ \$(grep -cxF '.ai-backbone/' .graphifyignore) = 1 ] && [ \$(grep -cxF 'brain/' .graphifyignore) = 1 ] && ! grep -qxF '*.md' .graphifyignore"
# `graphify update .` was what every run after the first used, and it reads
# documents too: 141 of a game's 217 nodes were .md files (0.9.64). Three runs
# by now, the last two with a map already there.
check "a map that is already there is refreshed from code only, never with update" "[ \$(grep -cx 'extract . --code-only' '$fm/calls') = 3 ] && ! grep -q '^update' '$fm/calls'"
# The map draws no calls in Dart, so an agent asks the words as well. One saved
# file and one brand-new one name the word; the five folders that are not the
# project's code name it too and must stay out. brain/ and .references/ are
# ignored by git as well; the other three would show without the recipe's list.
echo "SwapGame is the game" >> src/README.md
mkdir -p brain/probe .archive .references/probe graphify-out
for where in brain/probe/n.md .archive/probe.dart .references/probe/r.dart graphify-out/GRAPH_REPORT.md .ai-backbone/probe.txt; do echo "SwapGame probe" > "$where"; done
check "uses finds a word in saved and in brand-new files, whole words only" "says '^src/README.md:[0-9]+:' just uses SwapGame && says '^src/lib/game.dart:1:' just uses SwapGame && ! says 'SwapGameBoard' just uses SwapGame && says '^2 line\(s\) in 2 file\(s\)' just uses SwapGame"
check "uses leaves out the backbone, the vault, the map, references and the archive" "says 'game.dart' just uses SwapGame && ! says probe just uses SwapGame"
check "uses answers calmly when no line names the word"  "just uses Zzyzx && says 'No line in this project names \"Zzyzx\"' just uses Zzyzx"
check "uses runs nothing a word asks it to"              "just uses '\$(touch $tmp/PWNED5)' && [ ! -e '$tmp/PWNED5' ]"
# 37 recipes on show is the ceiling, so `uses` took the place of the one nobody
# types: session-start runs the tool-release check once a week, under its
# private name, and it still runs by hand.
check "backbone-news gave up its place on show and still exists" "! says '(^| )backbone-news( |\$)' just --summary && just --show _backbone-news"
check "session-start asks for the tool releases by the name the recipe has" "grep -q 'just _backbone-news' '$root/.ai-backbone/core.just' && ! grep -q 'just backbone-news' '$root/.ai-backbone/core.just'"
rm -rf src/lib brain/probe .archive .references graphify-out .graphifyignore .ai-backbone/probe.txt "$fm"
git checkout -q -- src/README.md
# The seed files. Key and certificate files are secrets and live in brain/. save
# stages every file git does not ignore, so the ignore list is the only thing
# between an Android keystore next to the app and GitHub; it had .jks and not
# .keystore.
keys_ignored() { local e; for e in pem key p8 p12 pfx jks keystore mobileprovision; do git check-ignore -q "src/android/app/upload.$e" || return 1; done; }
check "no key or certificate file outside brain/ can be saved" "keys_ignored"
check "the editor is told Dart's two spaces, which its formatter writes" "awk '/^\\[/ {s=\$0} s ~ /[{,]dart[,}]/ && /^indent_size = 2\$/ {ok=1} END {exit !ok}' .editorconfig"
# VS Code writes comments into the files it keeps in .vscode/, and this is the
# extensions.json it makes, tabs and all (read out of Cursor 3.16.29, a VS Code
# build). check-json refused it, so a save was refused for a file the editor had
# written. A real save, because save runs the fixers first and then tries again.
mkdir -p .vscode
printf '{\n\t// See https://go.microsoft.com/fwlink/?LinkId=827846 to learn about workspace recommendations.\n\t// Extension identifier format: ${publisher}.${name}. Example: vscode.csharp\n\n\t// List of extensions which should be recommended for users of this workspace.\n\t"recommendations": [\n\t\t"dart-code.flutter"\n\t],\n\t// List of extensions recommended by VS Code that should not be recommended for users of this workspace.\n\t"unwantedRecommendations": [\n\t\t\n\t]\n}\n' > .vscode/extensions.json
check "a save is not refused for the file VS Code writes, comments and all" "just save 'chore: editor recommendations' && says '^chore: editor recommendations' git log -1 --format=%s"
git reset -q --hard
check "the second-day lens asks about any toolchain, with Rust and Flutter as its examples" "grep -q 'Dockerfile' .ai-backbone/templates/audit-lenses.md && grep -q 'pubspec.yaml' .ai-backbone/templates/audit-lenses.md"
echo x > stray.txt
check "doctor names a file that does not belong in the root" "says 'do not belong: stray.txt' just doctor"
# The three ways out of that warning, and then the same real stray again with all
# three in place — because an escape hatch that quietly widens to everything is
# how a check goes green and stops looking.
echo y > CONTRIBUTING.md
check "a file an arriving contributor looks for is not a stray" "! says CONTRIBUTING.md just _root-strays"
echo c > CHANGELOG.md
check "nor is the CHANGELOG.md the session skill asks a project to keep there" "! says CHANGELOG.md just _root-strays"
echo z > local-notes.txt && echo "local-notes.txt" >> .gitignore
check "what git ignores is not in the repository, so not misplaced in it" "! says local-notes.txt just _root-strays"
echo x > build.toml && printf '_root-allow:\n    @echo "build.toml"\n' > stack.just
check "the project names the root file its own language needs" "! says build.toml just _root-strays"
check "and the real stray is still named with all three in place" "says stray.txt just _root-strays"
rm -f stray.txt CONTRIBUTING.md local-notes.txt build.toml stack.just
git checkout -q HEAD -- .gitignore
check "Turkish project keeps the Turkish aliases"     "grep -q '^alias yedekle := save' Justfile"
check "adr gets a number and a slug"                  "just adr 'Neden SQLite' && grep -q '^# 0001 — Neden SQLite' docs/adr/0001-neden-sqlite.md"
# An agent's knowledge ends on a date, so a pinned version is read or measured, never
# remembered, and the decision says what it was measured on (3.20.0). Until then no
# rule, skill or template asked; one project had made it a habit by hand.
check "adr asks what its claims were measured on"     "grep -q '^\*\*Measured on:\*\*' docs/adr/0001-neden-sqlite.md"
check "session skill says an agent's knowledge ends on a date" "grep -q 'What you know ends on a date' .agents/skills/session/SKILL.md"
check "AGENTS.md refuses a pinned version from memory" "grep -q 'measured on <name> <version>' AGENTS.md"
check "the spec skill points at the rule"             "grep -q 'What you know ends on a date' .agents/skills/spec/SKILL.md"
echo old > src/eski.txt; git add -A; git commit -qm "feat: a file to retire" >/dev/null 2>&1
check "archive moves the file and adds the guide"     "just archive src/eski.txt && [ -f .archive/eski.txt ] && [ ! -f src/eski.txt ] && [ -f .archive/README.md ]"
# `just snapshot` promises a zip of the project without the heavy folders, and every
# one of its -x patterns began with `*/`, which zip matches only below the root. So a
# Rust project's target/ and a Node project's node_modules/ — the two that always sit
# at the root — were zipped whole (measured 2026-09-21 with zip 3.0). Both depths are
# planted here; the old patterns saw only the lower one.
# On Windows there is no zip and no unzip under Git Bash; its tar is bsdtar,
# which writes and lists zip archives, and the recipe uses it there (spec 020).
bt=$(just _bsdtar 2>/dev/null || true)
if command -v zip >/dev/null 2>&1 || [ -n "$bt" ]; then
  mkdir -p node_modules sub/node_modules target .venv
  for d in node_modules sub/node_modules target .venv; do echo heavy > "$d/f.txt"; done
  snap_list() { local z; z=$(just snapshot) || return 1; if command -v unzip >/dev/null 2>&1; then unzip -l "$z"; else "$bt" -tf "$z"; fi; }
  check "snapshot leaves out the heavy folders, at the root as well as below it" \
        "! says '(node_modules|target|build|dist|\.venv)/' snap_list && says 'src/README.md' snap_list"
  rm -rf node_modules sub target .venv .snapshots
else
  printf "  --    snapshot not checked: no zip and no bsdtar on this machine\n"
fi
# ref-add names the clone after the folder it came from, so the name looked for is
# this checkout's own. The literal word ai-backbone turned the suite red in a second
# clone under any other name, and green again by accident wherever the word stood
# somewhere in the path, which is the `url` line and proves nothing about the name.
ref=$(basename "$root" | tr '[:upper:]' '[:lower:]')
check "ref-add adds the guide and the list"           "just ref-add '$root' 'the backbone itself' && [ -f .references/README.md ] && grep -qF 'name   = \"$ref\"' .references/references.toml && [ -d '.references/$ref' ]"
# A jump of many versions used to die with exit 141 after copying the files, and a
# rule the seed AGENTS.md gained reached no existing project unless somebody read the
# changelog (3.20.0). 3.5.0 is planted because the 3.6.0 entry names AGENTS.md, and
# saved, because the version a project is on is read from its last save. One
# run, read three times: the herestrings read a variable, not a pipe.
perl -pi -e 's/version [0-9.]+/version 3.5.0/ if $.==1' .ai-backbone/core.just
git commit -qam "chore: an old backbone" --no-verify >/dev/null 2>&1
out=$(just template-update 2>&1); rc=$?
check "template-update survives a span of many versions"  "[ $rc -eq 0 ] && grep -q '^Next: just sync-rules' <<<\"\$out\""
check "and says how much of the span it left in the file"  "grep -qE 'and [0-9]+ more lines in \.ai-backbone/CHANGELOG\.md' <<<\"\$out\""
check "template-update says when the rules gained a line the seed will not carry"  "grep -q 'names AGENTS.md' <<<\"\$out\""
check "and is quiet once nothing is behind"           "says 'Already up to date' just template-update"
check "hook config is the project's: an edit survives template-update" "echo '# mine' >> .pre-commit-config.yaml && says 'Already up to date' just template-update && grep -q '^# mine' .pre-commit-config.yaml"
git checkout -q -- .pre-commit-config.yaml 2>/dev/null || true
# A note from a project lands in the backbone's docs/backlog.md. A stand-in backbone keeps the real one clean.
mkdir -p "$tmp/bb/.ai-backbone" && cp "$root/.ai-backbone/manifest.txt" "$tmp/bb/.ai-backbone/"
( cd "$tmp/bb" && git init -qb main && git add -A && git commit -qm "chore: stand-in backbone" ) >/dev/null 2>&1
check "backbone-note lands in the backbone's backlog with date and project" "AI_BACKBONE='$tmp/bb' just backbone-note 'save says the wrong thing' && grep -q '^- \[ \] $(date +%Y-%m-%d), Deneme Projesi: save says the wrong thing' '$tmp/bb/docs/backlog.md'"
check "backbone-note saves the note in the backbone by itself"  "says '^docs: backlog note$' git -C '$tmp/bb' log -1 --format=%s && [ -z \"\$(git -C '$tmp/bb' status --short)\" ]"
check "backbone-note runs nothing a note asks it to"   "AI_BACKBONE='$tmp/bb' just backbone-note '\$(touch $tmp/PWNED2)' && [ ! -e '$tmp/PWNED2' ] && grep -qF ': \$(touch $tmp/PWNED2)' '$tmp/bb/docs/backlog.md'"
check "backbone-note with no backbone nearby writes nothing"  "! AI_BACKBONE='$tmp/none' just backbone-note 'x' && [ ! -d '$tmp/none' ]"
# spec 013, save-ci-update: what save, ci, publish and template-update learned
# while the backlog was cleared. The checks have a project of their own, so that
# nothing planted here reaches the checks around them.
echo "== save, ci and template-update (spec 013) =="
( cd "$root" && just new-project "$tmp/s13" tr ) >/dev/null 2>&1
cd "$tmp/s13" || exit 1
# In a linked git worktree `.git` is a file, and `[ -d .git ]` sent an agent
# working in one away with "No git repo yet". The hooks of a worktree are the
# main folder's, so they are taken away there and looked for there.
git worktree add -q "$tmp/s13-linked" -b side >/dev/null 2>&1
check "save works in a linked worktree"               "( cd '$tmp/s13-linked' && echo x >> README.md && just save 'docs: from a linked worktree' ) && says '^docs: from a linked worktree\$' git -C '$tmp/s13-linked' log -1 --format=%s"
check "and ci does not call one \"no repository\""      "( cd '$tmp/s13-linked' && ! says 'No git repo' just ci )"
rm -f .git/hooks/pre-commit .git/hooks/commit-msg
( cd "$tmp/s13-linked" && just template-update ) >/dev/null 2>&1
check "template-update in one puts the hooks back where git looks for them" "[ -f .git/hooks/pre-commit ] && [ -f .git/hooks/commit-msg ]"
just hooks-install >/dev/null 2>&1
# The other half of the question, and the reason it is not `git rev-parse
# --git-dir`: that succeeds in a plain folder inside somebody else's repository
# too, and from there the `git add -A` of a save stages the whole of it. This
# check was green before the change too; it is red against that shorter fix.
mkdir -p nested/.ai-backbone && cp .ai-backbone/core.just nested/.ai-backbone/ && cp AGENTS.md nested/ && printf "import '.ai-backbone/core.just'\n" > nested/Justfile
check "a folder inside somebody else's repository is still not one, and a save there stages nothing" "( cd nested && says 'No git repo yet' just save x ) && [ -z \"\$(git diff --cached --name-only)\" ]"
rm -rf nested
# A file over the size limit, which is 5,000 KB and was not raised: nobody has
# measured a real asset yet. The refusal said "fix what the check above says",
# which gives somebody who is no programmer nothing to do, and the file stayed
# staged, so the agent that ignored it was refused again for the same file.
# 5,324,800 bytes are 5,200 KB whichever way a hook rounds (prek down, pre-commit up).
head -c 5324800 /dev/zero > src/big.bin
out=$(just save 'feat: a big file' 2>&1); rc=$?
check "a save stopped by a big file names the file and the limit" "[ $rc -ne 0 ] && grep -q '^  src/big.bin (5200 KB)\$' <<<\"\$out\" && grep -q 'en çok 5000 KB' <<<\"\$out\""
check "and says whose job it is and what that agent does next" "grep -q 'ajanının işi' <<<\"\$out\" && grep -q '^Ajan: .*gitignore' <<<\"\$out\" && ! grep -q 'Yukarıdaki kontrolün' <<<\"\$out\""
echo 'src/big.bin' >> .gitignore
check "once the agent has ignored the file, the next save goes through" "just save 'chore: a file that does not belong here' && ! says 'big.bin' git ls-files"
echo x >> README.md
check "any other refusal still gets the general line"   "says 'Yukarıdaki kontrolün dediğini düzelt' just save 'özellik: türkçe bir mesaj'"
git reset -q --hard
perl -pi -e 's/^\| chat_lang \| tr \|/| chat_lang | en |/' AGENTS.md
check "and an English project reads it in English"      "says 'Too big for a save .%s KB at most.:' just _msg too-big && says '^Agent: .*gitignore' just _msg too-big-next"
git checkout -q -- AGENTS.md
# Checks that are switched off on GitHub (Settings, Actions). The run list of
# such a repository answers like any other, with nothing or with its old runs,
# so ci said "They start on the next push" about checks that never will, or
# called a commit that was on GitHub unsent; and publish promised "The checks
# start now" every time. A stand-in for gh answers as GitHub did on 2026-09-19:
# `false` from actions/permissions, asked with -q .enabled.
mkdir -p .github/workflows "$tmp/gh13" && printf 'on: push\n' > .github/workflows/checks.yml
git init -q --bare "$tmp/s13-hub.git" && git remote add origin "$tmp/s13-hub.git"
cat > "$tmp/gh13/gh" <<'EOF'
#!/bin/sh
case "$1 $2" in
  "auth status") exit 0 ;;
  "run list") case "$*" in *--commit*) ;; *) [ -z "${FAKE_OLD_RUNS:-}" ] || printf '1\tchecks\t0000000\tmain\tcompleted\tsuccess\t2026-01-01T10:00:00Z\tpush\thttps://github.com/example/repo/actions/runs/1\tan old push\n' ;; esac ;;
  "run view") printf 'rust\tcompleted\tsuccess\t7\t-\n' ;;
  "repo view") echo "https://github.com/example/repo" ;;
  "api "*) case "$*" in *actions/permissions*) echo "${FAKE_ACTIONS:-false}" ;; esac ;;
esac
EOF
chmod +x "$tmp/gh13/gh"
gh13() { env AI_BACKBONE_OFFLINE= PATH="$tmp/gh13:$PATH" "$@"; }
check "ci says when the checks are switched off on GitHub, and where they go back on" "says 'switched off' gh13 just ci && says 'github.com/example/repo/settings/actions' gh13 just ci && ! says 'start on the next push' gh13 just ci"
check "and does not call the commit unsent because old runs are all it finds" "says 'switched off' gh13 FAKE_OLD_RUNS=1 just ci && ! says 'has not reached GitHub' gh13 FAKE_OLD_RUNS=1 just ci"
check "checks that are on and have never run still read as before" "says 'never run here. They start on the next push' gh13 FAKE_ACTIONS=true just ci"
check "publish promises no checks where they are switched off" "says 'gönderildi' gh13 just publish && ! says 'checks start now' gh13 just publish"
check "and still does where they are on"                "says 'checks start now' gh13 FAKE_ACTIONS=true just publish"
git remote remove origin; rm -rf .github
# The version a project is on is the one in its last save. An update that was
# copied and never saved left four projects with 3.7.0 committed and 3.17.1 on
# disk; the next update read the disk, and what ten versions had to say about
# AGENTS.md was never shown. Here 3.5.0 is saved, and the second run finds
# 3.19.0 on disk, unsaved: both must leave the same number of lines unshown.
perl -pi -e 's/version [0-9.]+/version 3.5.0/ if $.==1' .ai-backbone/core.just
git commit -qam "chore: an old backbone" --no-verify >/dev/null 2>&1
unshown() { sed -nE 's/.* and ([0-9]+) more lines in .*/\1/p' <<<"$1"; }
whole=$(unshown "$(just template-update 2>&1)")
perl -pi -e 's/version [0-9.]+/version 3.19.0/ if $.==1' .ai-backbone/core.just
half=$(unshown "$(just template-update 2>&1)")
check "template-update reads the span from the last save, not from an update left half applied" "[ -n '$whole' ] && [ '$half' = '$whole' ]"
# AGENTS.md is a seed, so a rule the backbone gained reaches no project that was
# already there. template-update says which ones: a rule is taken out of each of
# the three sections that grow, and a fourth is reworded in case and punctuation
# only, which is the same rule still.
perl -0pi -e 's/^- Never leave a session with uncommitted work\.\n//m; s/^- `just undo` throws away[^\n]*\n//m; s/^- Do not invent a command\.[^\n]*\n//m; s/^- Ask first before: /- ask first, before /m' AGENTS.md
lack=$(just template-update 2>&1)
check "template-update lists the seed rules this AGENTS.md lacks, from each of the three sections" "grep -q '^  - Never leave a session' <<<\"\$lack\" && grep -qF '  - \`just undo\` throws away' <<<\"\$lack\" && grep -q '^  - Do not invent a command' <<<\"\$lack\""
check "and no other: a rule reworded only in case and punctuation is not listed" "[ \$(grep -c '^  - ' <<<\"\$lack\") -eq 3 ]"
check "and the file is left as it was found"            "! grep -q 'Never leave a session' AGENTS.md && grep -q '^- ask first, before ' AGENTS.md"
git checkout -q -- AGENTS.md
check "and nothing is said about rules when none is missing" "! says 'first six' just template-update"
cd "$p" || exit 1

# The clone the notes cross (3.21.0). A scheduled agent pushes to GitHub every
# day, so a note is usually written on yesterday's tree. It used to be refused,
# called "not reachable", and leave the clone ahead and behind, where a
# fast-forward never works again and nothing said so. Here: a bare folder stands
# in for GitHub, `bb` is the maintainer's clone of it, `agent` pushes like the
# scheduled run. The remotes are folders, so the offline switch is lifted for
# these lines and nothing leaves the machine.
echo "== the backbone's clone keeps itself level =="
hub="$tmp/level"; mkdir -p "$hub/seed/docs" "$hub/seed/.ai-backbone"
( cd "$hub" && git init -q --bare -b main remote.git && cd seed && git init -qb main \
  && cp "$root/.ai-backbone/manifest.txt" .ai-backbone/ && cp "$root/.gitattributes" . \
  && printf '# ai-backbone\n' > README.md && printf '# core.just, version 1.0.0\n' > .ai-backbone/core.just \
  && printf '# Backlog\n\n- [ ] 2026-01-01, a: first\n- [ ] 2026-01-02, b: second\n' > docs/backlog.md \
  && git add -A && git commit -qm "chore: seed" && git remote add origin ../remote.git && git push -q origin main \
  && cd .. && git clone -q remote.git bb && git clone -q remote.git agent ) >/dev/null 2>&1
moved()  { ( cd "$hub/agent" && git pull -q --rebase origin main && eval "$1" && git add -A && git commit -qm "fix: the scheduled agent" && git push -q origin HEAD ) >/dev/null 2>&1; }
onhub()  { git -C "$hub/remote.git" show "main:${1:-docs/backlog.md}"; }
online() { env -u AI_BACKBONE_OFFLINE AI_BACKBONE="$hub/bb" "$@"; }
level()  { git -C "$hub/bb" fetch -q origin main && [ "$(git -C "$hub/bb" rev-list --count HEAD...origin/main)" = 0 ] && [ -z "$(git -C "$hub/bb" status --short)" ]; }
rewind() { git -C "$hub/bb" reset -q --hard origin/main; }
moved "printf -- '- [ ] 2026-01-03, agent: third\n' >> docs/backlog.md"
check "a note written while GitHub has moved is sent"  "says 'sent +to GitHub' online just backbone-note 'written on an old tree' && says 'written on an old tree' onhub && says 'agent: third' onhub && level"
git -C "$hub/bb" remote set-url origin "$hub/nowhere.git"
check "a note that cannot reach GitHub says that, and only that" "says 'not sent: GitHub not reachable' online just backbone-note 'while GitHub was away'"
git -C "$hub/bb" remote set-url origin "$hub/remote.git"
moved "perl -pi -e 's/^- \[ \] (2026-01-02.*)\$/- [x] \$1 — done in 9.9.9/' docs/backlog.md && printf -- '- [ ] 2026-01-04, agent: fourth\n' >> docs/backlog.md"
check "a clone ahead and behind is level after the next project session" "says 'sent 1 note' online just _backbone-refresh '$hub/bb' && level && says 'while GitHub was away' onhub && says 'agent: fourth' onhub && says '^- \[x\] 2026-01-02' onhub && ! says '^(<<<<<<<|=======|>>>>>>>)' onhub"
( cd "$hub/bb" && printf '# ai-backbone, edited here\n' > README.md && git commit -qam "docs: saved here" ) >/dev/null 2>&1
moved "printf '# ai-backbone, edited there\n' > README.md"
check "work that does not fit is said, never 'up to date', and no rebase is left behind" "says 'do not fit together' online just _backbone-level '$hub/bb' GitHub && ! says 'up to date' online just _backbone-level '$hub/bb' GitHub && [ ! -d '$hub/bb/.git/rebase-merge' ] && [ ! -d '$hub/bb/.git/rebase-apply' ] && [ -z \"\$(git -C '$hub/bb' status --short)\" ]"
was=$(git -C "$hub/bb" rev-parse HEAD)
check "a project's session never rebases saved work from outside, and says what it is compared with may be old" "says 'Backbone: .*saved but unpublished.*may be old' online just _backbone-refresh '$hub/bb' && [ \$(git -C '$hub/bb' rev-parse HEAD) = $was ]"
rewind
( cd "$hub/bb" && echo x >> README.md && git commit -qam "docs: saved, not published" ) >/dev/null 2>&1
check "saved work nobody published is said, and not pushed for them" "says 'not on GitHub yet -> just publish' online just _backbone-level '$hub/bb' GitHub && ! says 'saved, not published' git -C '$hub/remote.git' log --format=%s main"
rewind
printf '#!/bin/sh\nexit 1\n' > "$hub/bb/.git/hooks/pre-commit" && chmod +x "$hub/bb/.git/hooks/pre-commit"
check "a note the backbone's own checks refuse is never called sent" "says 'not saved: the backbone.s own checks refused' online just backbone-note 'refused' && ! says 'sent' online just backbone-note 'refused again'"
mv "$hub/bb/.git/hooks/pre-commit" "$hub/bb/.git/hooks/pre-commit.off"; git -C "$hub/bb" reset -q; git -C "$hub/bb" checkout -q -- docs/backlog.md
git -C "$hub/bb" checkout -q -b side
check "a clone that is not on main says so, twice, and sends nothing" "says \"not brought up to date: .* is on 'side'\" online just backbone-note 'from a side branch' && ! says 'from a side branch' onhub"
git -C "$hub/bb" checkout -q main; git -C "$hub/bb" branch -q -D side
lines=$(grep -c '^- \[' "$hub/bb/docs/backlog.md")
online just backbone-note "$(printf 'first half\n- [ ] 2020-01-01, agent: a forged line\tand a tab')" >/dev/null 2>&1
check "a note with a newline in it writes one line"    "[ \$(grep -c '^- \[' '$hub/bb/docs/backlog.md') -eq $((lines+1)) ] && grep -q 'first half - \[ \] 2020-01-01, agent: a forged line and a tab\$' '$hub/bb/docs/backlog.md'"
# A note sends itself, never the saved work under it; and a tag is what GitHub's
# main says, never what this folder's files say (both measured the other way).
( cd "$hub/bb" && echo y >> README.md && git commit -qam "feat: half done, saved, not published" ) >/dev/null 2>&1
check "a note never publishes the saved work that sits under it" "says 'not sent: the backbone has saved work of its own' online just backbone-note 'over unpublished work' && ! says 'half done' git -C '$hub/remote.git' log --format=%s main"
rewind
printf '# core.just, version 1.0.1\n' > "$hub/bb/.ai-backbone/core.just"
# What the tag is read from, printed only when this fails: on Windows no tag
# reached the hub and nothing said why (spec 020).
check "a version bumped in unsaved work is not tagged on the commit before it" "{ git -C '$hub/bb' show origin/main:.ai-backbone/core.just; git -C '$hub/bb' remote -v; git -C '$hub/bb' ls-remote --tags origin; git -C '$hub/bb' tag; } 2>&1 | sed 's/^/diag: /'; online just _backbone-refresh '$hub/bb' && ! says 'v1.0.1' git -C '$hub/remote.git' tag && says 'v1.0.0' git -C '$hub/remote.git' tag"
git -C "$hub/bb" checkout -q -- .ai-backbone/core.just
# One at a time in that clone: a second session leaves quietly while the first
# works, and a lock left by a run that died is cleared after ten minutes.
moved "printf -- '- [ ] 2026-01-06, agent: sixth\n' >> docs/backlog.md"
mkdir "$hub/bb/.git/backbone-level.lock"; had=$(git -C "$hub/bb" rev-list --count HEAD)
check "while one session brings the clone level, a second one leaves it alone" "online just _backbone-refresh '$hub/bb' && [ \$(git -C '$hub/bb' rev-list --count HEAD) -eq $had ]"
touch -t 202001010000 "$hub/bb/.git/backbone-level.lock"
check "a lock left by a run that died is cleared"      "says 'pulled 1 new commit' online just _backbone-refresh '$hub/bb' && [ ! -d '$hub/bb/.git/backbone-level.lock' ]"
# A scheduled run's checkout has no branch and is exactly what GitHub has.
git clone -q "$hub/remote.git" "$hub/cloud" >/dev/null 2>&1 && git -C "$hub/cloud" checkout -q --detach origin/main
check "a checkout with no branch that is what GitHub has is called up to date" "says 'GitHub: up to date \(a checkout with no branch' online just _backbone-level '$hub/cloud' GitHub"
git -C "$hub/bb" checkout -q --detach
check "a note is never written into a clone that would lose it" "! online just backbone-note 'onto no branch' && says 'Nothing written' online just backbone-note 'onto no branch' && ! grep -q 'onto no branch' '$hub/bb/docs/backlog.md'"
git -C "$hub/bb" checkout -q main
# One checkout with no branch is not that: a scheduled run's own. It is what
# GitHub has. 3.21.0 refused it too, so the agent that works on the backbone
# every day could leave no note (3.22.0); 3.22.0 pushed it to main by name, and
# since spec 017 that push would carry the run's untested work, so the note is
# saved and rides the run's own push to cloud. The stand-in has no recipes of
# its own, so the suite's are pointed at it.
incloud() { env -u AI_BACKBONE_OFFLINE -u AI_BACKBONE JUST_JUSTFILE="$root/Justfile" JUST_WORKING_DIRECTORY="$hub/cloud" "$@"; }
git -C "$hub/cloud" fetch -q origin main && git -C "$hub/cloud" checkout -q --detach origin/main
check "a scheduled run's checkout, which has no branch, saves a note that rides its push, and sends nothing itself" "says 'rides the next push to cloud' incloud just backbone-note 'idea: from a checkout with no branch' && grep -q 'from a checkout with no branch' '$hub/cloud/docs/backlog.md' && ! says 'from a checkout with no branch' onhub && says '^docs: backlog note' git -C '$hub/cloud' log -1 --format=%s"
git -C "$hub/bb" pull -q --rebase origin main >/dev/null 2>&1
moved "echo '# x' >> .gitignore"
check "a pulled change to the agent's own guard rails is said out loud" "says 'guard rails: .*\.gitignore' online just _backbone-refresh '$hub/bb'"
moved "printf -- '- [ ] 2026-01-05, agent: fifth\n' >> docs/backlog.md"
had=$(git -C "$hub/bb" rev-list --count HEAD)
check "offline, the clone is left alone"               "AI_BACKBONE='$hub/bb' just _backbone-refresh '$hub/bb' && [ \$(git -C '$hub/bb' rev-list --count HEAD) -eq $had ]"
# spec 017: the branch the runs push to. `cc` is an attended session's clone on
# cloud: levelled by a merge, never pushed from here, never pulling main. From a
# project it is named and nothing is copied from it. A gate that stopped is
# heard everywhere, once cloud has been ahead of main for two days. And inside
# the backbone, main is the gate's to move: publish and save refuse it.
( cd "$hub/agent" && git push -q origin main:cloud && cd .. && git clone -q remote.git cc && git -C cc checkout -q cloud ) >/dev/null 2>&1
oncloud() { ( cd "$hub/agent" && git fetch -q origin cloud && git checkout -q -B cloud origin/cloud && eval "$1" && git add -A && git commit -qm "${2:-feat: on cloud}" && git push -q origin cloud && git checkout -q main ) >/dev/null 2>&1; }
( cd "$hub/cc" && echo local >> README.md && git commit -qam "feat: saved on cloud here" ) >/dev/null 2>&1
oncloud "echo theirs > theirs.txt"
moved "printf -- '- [ ] 2026-01-08, agent: eighth\n' >> docs/backlog.md"
check "a clone on cloud takes what is new there by a merge, never pulls main, and pushes nothing" "says 'pulled 1 new commit' online just _backbone-level '$hub/cc' GitHub && [ -n \"\$(git -C '$hub/cc' log --merges -1 --format=%h)\" ] && [ ! -d '$hub/cc/.git/rebase-merge' ] && ! grep -q 'agent: eighth' '$hub/cc/docs/backlog.md' && says 'not on GitHub yet -> just publish' online just _backbone-level '$hub/cc' GitHub && ! says 'saved on cloud here' git -C '$hub/remote.git' log --format=%s cloud"
check "from a project, a sibling on cloud is named and left alone" "says \"on 'cloud', not on main, and what projects copy from it is untested\" env -u AI_BACKBONE_OFFLINE AI_BACKBONE='$hub/cc' just _backbone-refresh '$hub/cc'"
check "and template-update copies nothing from it"      "! env -u AI_BACKBONE_OFFLINE AI_BACKBONE='$hub/cc' just template-update && says 'Not updated: .* on .cloud., not on main' env -u AI_BACKBONE_OFFLINE AI_BACKBONE='$hub/cc' just template-update"
( cd "$hub/agent" && git checkout -q -B cloud origin/cloud && echo old > old.txt && git add -A && GIT_COMMITTER_DATE='2020-01-01T00:00:00Z' GIT_AUTHOR_DATE='2020-01-01T00:00:00Z' git commit -qm "feat: waiting at the gate" && git push -q origin cloud && git checkout -q main ) >/dev/null 2>&1
check "once cloud has been ahead of main for two days, both voices say so" "says 'cloud is [0-9]+ commit\(s\) ahead of main, the oldest [0-9]+ days old' online just _backbone-level '$hub/bb' GitHub && says 'Backbone: cloud is [0-9]+ commit' online just _backbone-refresh '$hub/bb'"
( cd "$hub/agent" && git push -q -f origin main:cloud && git checkout -q -B cloud origin/cloud && echo young > young.txt && git add -A && git commit -qm "feat: pushed today" && git push -q origin cloud && git checkout -q main ) >/dev/null 2>&1
check "and not while the oldest of them is younger"     "! says 'ahead of main, the oldest' online just _backbone-level '$hub/bb' GitHub"
moved "mkdir -p .github/workflows && echo 'on: push' > .github/workflows/checks.yml"
check "a pulled change to the workflows is said out loud too" "says 'guard rails: .*\.github/workflows/checks\.yml' online just _backbone-refresh '$hub/bb'"
inbb() { env -u AI_BACKBONE_OFFLINE -u AI_BACKBONE PATH="$tmp/gh13:$PATH" JUST_JUSTFILE="$root/Justfile" JUST_WORKING_DIRECTORY="$hub/bb" "$@"; }
( cd "$hub/bb" && git pull -q --rebase origin main && echo p >> README.md && git commit -qam "feat: to publish" ) >/dev/null 2>&1
check "inside the backbone, publish on main is refused and names cloud" "! inbb just publish && says 'travels on cloud' inbb just publish && says 'git checkout -B cloud origin/cloud' inbb just publish && ! says 'to publish' git -C '$hub/remote.git' log --format=%s main"
git -C "$hub/bb" config ai-backbone.publish-on-save true; echo q >> "$hub/bb/README.md"
check "and a save with publish-on-save saves and pushes nothing" "says 'not sent to GitHub: the backbone.s work travels on cloud' inbb just save 'docs: saved, not pushed' && ! says 'saved, not pushed' git -C '$hub/remote.git' log --format=%s main"
( cd "$hub/bb" && git checkout -q -B cloud origin/cloud && git merge -q --no-edit main ) >/dev/null 2>&1
check "on cloud, publish sends to cloud and nothing reaches main" "says 'Sent to GitHub' inbb just publish && says 'to publish' git -C '$hub/remote.git' log --format=%s cloud && ! says 'to publish' git -C '$hub/remote.git' log --format=%s main"
( cd "$hub/bb" && git checkout -q main && git reset -q --hard origin/main && git config --unset ai-backbone.publish-on-save ) >/dev/null 2>&1

# spec 017: the gate. What passes on cloud reaches main, and nothing else does.
# A bare folder stands in for GitHub with main and cloud; `work` pushes to cloud
# the way a run does; `judge` is the promote job's checkout of main; a stand-in
# gh answers what the run's jobs said (the log lines in the shape of
# fixtures/gh-log-failed.txt). Nothing leaves the machine.
echo "== the gate: what passes on cloud reaches main =="
gt="$tmp/gate"; mkdir -p "$gt/gh"
( cd "$gt" && git init -q --bare -b main hub.git && git clone -q hub.git seed && cd seed \
  && mkdir -p docs .ai-backbone .github/workflows \
  && printf '# .ai-backbone/core.just — recipes, version 1.0.0\n' > .ai-backbone/core.just \
  && printf 'on: push\n' > .github/workflows/checks.yml && cp "$root/.ai-backbone/gate.sh" .ai-backbone/gate.sh \
  && printf -- '- 2026-01-01 1.0.0: seed\n' > docs/routine-log.md && echo x > README.md \
  && git add -A && git commit -qm "chore: seed" && git push -q origin main && git push -q origin main:cloud \
  && cd .. && git clone -q hub.git work && git -C work checkout -q cloud && git clone -q hub.git judge ) >/dev/null 2>&1
cat > "$gt/gh/gh" <<'EOF'
#!/bin/sh
case "$*" in
  *"--json jobs"*) printf '%s\n' "${FAKE_JOBS:-}" | tr '|' '\n' ;;
  *"--log-failed"*) printf '%s\n' "${FAKE_LOG:-}" | tr '|' '\n' ;;
esac
EOF
chmod +x "$gt/gh/gh"
gate()     { ( cd "${1:-$gt/work}" && bash "$root/.ai-backbone/gate.sh" look 2>/dev/null | tail -1 ); }
pushed()   { ( cd "$gt/work" && eval "$1" >/dev/null && git add -A && git commit -qm "${2:-feat: on cloud}" && git push -q origin HEAD:cloud && git rev-parse HEAD ) 2>/dev/null; }
judge()    { ( cd "$gt/judge" && env PATH="$gt/gh:$PATH" FAKE_JOBS="${3:-}" FAKE_LOG="${4:-}" GATE_SHA="$1" GATE_ENDED="$2" GATE_RUN=77 bash "$root/.ai-backbone/gate.sh" carry ); }
hubmain()  { git -C "$gt/hub.git" rev-parse main; }
hubtag()   { git -C "$gt/hub.git" rev-parse -q --verify "refs/tags/$1" 2>/dev/null; }
cloudlog() { git -C "$gt/hub.git" show cloud:docs/routine-log.md; }
loglines() { awk 'END { print NR }' <<<"$(cloudlog)"; }
synced()   { git -C "$gt/work" pull -q --no-rebase origin cloud >/dev/null 2>&1; }
TAB=$'\t'
GREEN="1${TAB}look${TAB}success|2${TAB}suite (ubuntu-latest)${TAB}success|3${TAB}suite (macos-latest)${TAB}success|4${TAB}suite (windows-latest)${TAB}success"
s=$(pushed "echo '- a log line' >> docs/routine-log.md && echo '- [ ] a note' >> docs/backlog.md && echo z > docs/radar.toml && mkdir -p docs/specs && echo s > docs/specs/099-x.md" "docs: the routine's own files")
check "look: a push that changes only the routine's own files is docs-only" "[ \"\$(gate)\" = docs-only ]"
git clone -q --depth 1 -b cloud "$gt/hub.git" "$gt/shallow" >/dev/null 2>&1
check "and a checkout of depth one answers the same"   "[ \"\$(gate '$gt/shallow')\" = docs-only ]"
s=$(pushed "echo g > docs/01-getting-started.md" "docs: a page the suite reads")
check "look: any other page under docs/ runs the suite" "[ \"\$(gate)\" = suite ]"
( cd "$gt/shallow" && git fetch -q --depth 1 origin cloud && git checkout -q FETCH_HEAD ) >/dev/null 2>&1
check "in a checkout of depth one too"                  "[ \"\$(gate '$gt/shallow')\" = suite ]"
s=$(pushed "printf '# .ai-backbone/core.just — recipes, version 1.0.1\n' > .ai-backbone/core.just" "feat: 1.0.1")
check "look: code runs the suite"                       "[ \"\$(gate)\" = suite ]"
check "carry: a green run is carried to main and its version tagged, in one push" "says 'carried .* to main and tagged v1.0.1' judge $s success '$GREEN' && [ \$(hubmain) = $s ] && [ \"\$(hubtag v1.0.1)\" = $s ]"
lines=$(loglines)
check "carried again, it says so and writes nothing"    "says 'on main already' judge $s success '$GREEN' && [ \$(loglines) -eq $lines ]"
s=$(pushed "echo y >> README.md" "feat: red")
check "a cancelled run is not judged"                   "says 'was cancelled' judge $s cancelled && [ \$(hubmain) != $s ] && [ \$(loglines) -eq $lines ]"
# Windows decides too (spec 020, the maintainer's word of 2026-09-24): a Windows
# job cut by its cap, or red, is not carried, however green the other two are.
CUT="1${TAB}look${TAB}success|2${TAB}suite (ubuntu-latest)${TAB}success|3${TAB}suite (macos-latest)${TAB}success|4${TAB}suite (windows-latest)${TAB}cancelled"
s=$(pushed "echo cut >> README.md" "feat: windows cut by its cap")
check "one cancelled by the Windows cap is not carried: Windows decides too" "says 'was cancelled' judge $s cancelled '$CUT' && [ \$(hubmain) != $s ]"
WINRED="1${TAB}look${TAB}success|2${TAB}suite (ubuntu-latest)${TAB}success|3${TAB}suite (macos-latest)${TAB}success|4${TAB}suite (windows-latest)${TAB}failure"
WINLOG="suite (windows-latest)${TAB}the suite${TAB}2026-01-02T03:00:02Z   FAIL  a windows check"
check "and a red Windows job with the other two green is not carried, and is named" "says 'not promoted' judge $s failure '$WINRED' '$WINLOG' && [ \$(hubmain) != $s ] && says 'suite \(windows-latest\) failure FAIL: a windows check' cloudlog"
GHOST="1${TAB}look${TAB}success|2${TAB}suite (ubuntu-latest)${TAB}success|3${TAB}suite (macos-latest)${TAB}success|4${TAB}suite (windows-latest)${TAB}success|5${TAB}something else${TAB}cancelled"
check "a run cancelled by a job that is not a suite job, all three suites green, is carried" "o=\$(judge $s cancelled '$GHOST' 2>&1); grep -q 'every suite job was green: they decide' <<<\"\$o\" && grep -qE 'carried .* to main' <<<\"\$o\" && [ \$(hubmain) = $s ]"
synced; lines=$(loglines); s=$(pushed "echo y2 >> README.md" "feat: red again")   # synced and counted again: the red Windows line above moved cloud
RED="1${TAB}look${TAB}success|2${TAB}suite (ubuntu-latest)${TAB}success|9${TAB}suite (macos-latest)${TAB}failure|10${TAB}suite (windows-latest)${TAB}failure"
LOG="suite (macos-latest)${TAB}the suite${TAB}2026-01-02T03:00:00Z   FAIL  a mac check|suite (macos-latest)${TAB}the suite${TAB}2026-01-02T03:00:01Z   FAIL  another one|suite (windows-latest)${TAB}the suite${TAB}2026-01-02T03:00:02Z   FAIL  windows noise"
check "a red run writes one line on cloud naming each red machine and its FAIL names" "says 'not promoted' judge $s failure '$RED' '$LOG' && [ \$(loglines) -eq $((lines+1)) ] && says '^- [0-9-]+ gate: cloud not promoted — the checks ended failure: suite \(macos-latest\) failure FAIL: a mac check;another one; suite \(windows-latest\) failure FAIL: windows noise;\$' cloudlog && [ \$(hubmain) != $s ]"
synced; s=$(pushed "echo 'on: pull_request' > .github/workflows/checks.yml" "ci: weaken")
check "a push that changes the workflows is refused, green or not" "says 'changes .github/workflows' judge $s success '$GREEN' && [ \$(hubmain) != $s ]"
synced; s=$(pushed "git checkout origin/main -- .github/workflows && echo '# x' >> .ai-backbone/gate.sh" "ci: weaken the judge")
check "and so is one that changes gate.sh"              "says 'changes .github/workflows or gate.sh' judge $s success '$GREEN' && [ \$(hubmain) != $s ]"
synced; s=$(pushed "git checkout origin/main -- .ai-backbone/gate.sh && echo w >> README.md" "feat: code")
check "a green run whose suite never ran is refused: a look weakened on cloud passes no code" "says 'suite was due' judge $s success '1${TAB}look${TAB}success' && [ \$(hubmain) != $s ]"
( cd "$gt" && git clone -q hub.git other && cd other && echo '- [ ] 2026-01-03, p: a note' >> docs/backlog.md && git add -A && git commit -qm "docs: backlog note from p" && git push -q origin main ) >/dev/null 2>&1
check "main that moved is not fast-forwarded, and the line says what joins them" "says 'main moved' judge $s success '$GREEN' && [ \$(hubmain) != $s ] && says 'the next run merges origin/main into cloud' cloudlog"
synced; s=$( cd "$gt/work" && git fetch -q origin main && git merge -q --no-edit origin/main >/dev/null 2>&1 && git push -q origin HEAD:cloud && git rev-parse HEAD )
check "after the run merged main into cloud, the same work is carried" "says 'carried .* to main' judge $s success '$GREEN' && [ \$(hubmain) = $s ]"
git -C "$gt/hub.git" tag v1.0.2 "$(git -C "$gt/hub.git" rev-parse 'main~2')" >/dev/null 2>&1
s=$(pushed "printf '# .ai-backbone/core.just — recipes, version 1.0.2\n' > .ai-backbone/core.just" "feat: 1.0.2")
check "a tag GitHub has elsewhere is left alone and main is carried on its own" "says 'carried .* to main; v1.0.2 was tagged before' judge $s success '$GREEN' && [ \$(hubmain) = $s ] && [ \"\$(hubtag v1.0.2)\" != $s ]"
# spec 013, session-tools: what session-start says and what it remembers, the pin
# tools-update moves, and the Go hooks-install fetches when prek cannot. In a
# throwaway project of its own, so the checks around this block find the first
# one as they left it.
echo "== session-start, tools-update and hooks-install (spec 013) =="
st="$tmp/session-tools"
( cd "$root" && just new-project "$st" ) >/dev/null 2>&1
cd "$st" || exit 1
# The specs that are open. Until now a session began with the journal, the
# commits and the backlog, and nothing said that a spec was half built.
check "session-start is quiet about specs while none is open" "says '^=== LAST COMMITS' just session-start && ! says '^Spec |docs/specs' just session-start"
just spec 'first idea' >/dev/null 2>&1
printf -- '---\nstatus: approved\n---\n\n# 002\n\n## Acceptance\n\n- [ ] never counted\n\n## Tasks\n\n- [x] one\n- [~] half done, which is open: it runs\n      on to a second line\n- [ ] three\n' > docs/specs/002-second.md
printf -- '---\nstatus: done\n---\n\n# 003\n\n## Tasks\n\n- [ ] left open in a finished spec\n' > docs/specs/003-finished.md
out=$(just session-start 2>&1)
check "session-start names each open spec, how far it is, and its next task" "grep -q '^Spec 001-first-idea (draft, no code until approved): 0 of 1 tasks ticked\\. Next: Small steps' <<<\"\$out\" && grep -q '^Spec 002-second (approved): 1 of 3 tasks ticked\\. Next: half done, which is open: it runs …\$' <<<\"\$out\""
check "and leaves a finished spec out"                 "grep -q '^Spec 002' <<<\"\$out\" && ! grep -q '003-finished' <<<\"\$out\""
# No GitHub address, no second copy of the code. It asks git only, so the offline
# suite hears it too; the address below is never asked for anything.
check "a project with no GitHub address hears so at every session, offline too" "grep -q '^GitHub: no address yet.* -> just publish\$' <<<\"\$out\""
git remote add origin https://github.com/example/no-such-repo.git
check "and no longer once it has one"                  "says '^=== LAST COMMITS' just session-start && ! says '^GitHub: no address' just session-start"
git remote remove origin
# The weekly upstream check used up its week even when it had read nothing. The
# offline switch is lifted for these three, because offline the block never runs:
# there is no backbone nearby to bring level, the other weekly block is stamped,
# a proxy nothing listens on stands behind it all, and the only source is a kind
# upstream.py refuses before it asks anybody. The real upstream.py says the
# sentence session-start listens for; a stand-in plays the week that went well.
weekly() { env -u AI_BACKBONE_OFFLINE AI_BACKBONE="$tmp/none" https_proxy=$dead http_proxy=$dead no_proxy= just session-start; }
printf '[[watch]]\nname = "nowhere"\nsource = "nosuchkind:nothing"\npin = "1.0.0"\n' > docs/upstream.toml
touch .git/ai-backbone.last-check; rm -f .git/ai-backbone.last-upstream
check "a weekly check that read nothing does not use up the week" "says '^No source gave an answer' weekly && [ ! -e .git/ai-backbone.last-upstream ]"
printf 'raise SystemExit(1)\n' > .ai-backbone/upstream.py
check "nor does one that could not run, and it says so"  "says '^upstream: could not run' weekly && [ ! -e .git/ai-backbone.last-upstream ]"
printf 'print("Everything watched is current.")\n' > .ai-backbone/upstream.py
check "one that read something does"                     "says '^Everything watched' weekly && [ -e .git/ai-backbone.last-upstream ]"
cp "$root/.ai-backbone/upstream.py" .ai-backbone/upstream.py; rm -f docs/upstream.toml .git/ai-backbone.last-check .git/ai-backbone.last-upstream
# tools-update upgraded graphify and left its pin behind: 0.9.62 in the list, 0.9.64
# installed. Every tool is a stand-in and brew is off the PATH, as in the two
# tools-update checks above. Four rows: one to move, one a file holds, one a file
# holds with its keys in another order, one that is ahead of what is installed.
tu="$tmp/st-tools"; mkdir -p "$tu/bin" "$tu/work/docs"; ln -sf "$(command -v just)" "$tu/bin/just"
printf '#!/bin/sh\nexit 0\n' > "$tu/bin/uv"
printf '#!/bin/sh\necho "graphify 0.9.64"\n' > "$tu/bin/graphify"
printf '#!/bin/sh\necho "prek 0.5.3 (b7eb60271 2026-09-13)"\n' > "$tu/bin/prek"
chmod +x "$tu"/bin/*
cat > "$tu/work/docs/upstream.toml" <<'TOML'
[[watch]]
name = "map"
source = "github:Graphify-Labs/graphify"
pin = "0.9.62"   # by hand
why = "0.9.62 was the first to read this language"

[[watch]]
name = "scanner"
source = "github:gitleaks/gitleaks"
pin = "v8.30.1"
pinned_in = ".pre-commit-config.yaml"

[[watch]]
name = "hooks"
pinned_in = "somewhere.txt"
source = "github:j178/prek"
pin = "0.0.1"

[[watch]]
name = "just"
source = "github:casey/just"
pin = "v999.0.0"
TOML
cp "$tu/work/docs/upstream.toml" "$tu/before.toml"
tools_update() { env PATH="$tu/bin:/usr/bin:/bin" just -f "$root/Justfile" -d "$tu/work" tools-update; }
out=$(tools_update 2>&1)
check "tools-update moves the pin of a tool no file holds to what is installed, and says so" "grep -q '^docs/upstream.toml: map pin 0.9.62 -> 0.9.64' <<<\"\$out\" && grep -q '^pin = \"0.9.64\"   # by hand\$' '$tu/work/docs/upstream.toml'"
changed=$(diff "$tu/before.toml" "$tu/work/docs/upstream.toml")
check "and that one line only, once: not a pin a file holds, not one that is ahead" "[ \$(grep -c '^[<>]' <<<\"\$changed\") -eq 2 ] && ! says ' pin .* -> ' tools_update"
# hooks-install in a sandbox: prek wants a Go from go.dev, which is closed there.
# The stand-in prek prepares its hooks only when the go first on the PATH is the
# one it asked for, and names that one in the log file it was handed, as prek
# 0.5.3 does; the stand-in go is an old one that fetches a newer toolchain when
# GOTOOLCHAIN asks. No real prek and no real go is run, so lifting the offline
# switch fetches nothing.
hg="$tmp/st-go"; mkdir -p "$hg/bin" "$hg/state"
cat > "$hg/bin/prek" <<'EOF'
#!/bin/sh
[ "$1" = prepare-hooks ] || exit 0
echo try >> "$FAKE_STATE/tries"
case "$(go version 2>/dev/null)" in *go1.99.1*) exit 0 ;; esac
while [ $# -gt 0 ]; do [ "$1" = --log-file ] && log=$2; shift; done
[ -z "${log:-}" ] || printf 'TRACE Installing go version=1.99.1\nDEBUG Downloading url=https://go.dev/dl/go1.99.1.linux-amd64.tar.gz\n' > "$log"
printf 'error: Failed to install hook `gitleaks`\n  caused by: Failed to download go\n' >&2; exit 2
EOF
cat > "$hg/bin/go" <<'EOF'
#!/bin/sh
if [ "${GOTOOLCHAIN:-}" = go1.99.1 ] && [ -z "${FAKE_GO_CLOSED:-}" ]; then
  mkdir -p "$FAKE_STATE/toolchain/bin"
  printf '#!/bin/sh\necho "go version go1.99.1 linux/amd64"\n' > "$FAKE_STATE/toolchain/bin/go"; chmod +x "$FAKE_STATE/toolchain/bin/go"
  [ "$1 $2" = "env GOROOT" ] && echo "$FAKE_STATE/toolchain"; exit 0
fi
[ -z "${GOTOOLCHAIN:-}" ] || exit 1
echo "go version go1.22.2 linux/amd64"
EOF
chmod +x "$hg"/bin/*
hooks() { env "$@" FAKE_STATE="$hg/state" PATH="$hg/bin:$PATH" just hooks-install; }
tries() { local n; n=$(grep -c . "$hg/state/tries" 2>/dev/null); echo "${n:-0}"; }
check "hooks-install fetches the Go prek could not, through the Go that is there, and tries once more" "says 'could not download Go 1\\.99\\.1 from go\\.dev' hooks -u AI_BACKBONE_OFFLINE && [ \$(tries) -eq 2 ]"
out=$(hooks -u AI_BACKBONE_OFFLINE FAKE_GO_CLOSED=1 2>&1); rc=$?
check "and when that Go cannot fetch it either, says what prek said and leaves the hooks installed" "[ $rc -eq 0 ] && grep -q 'Failed to download go' <<<\"\$out\" && grep -q 'the first save tries again' <<<\"\$out\" && grep -q '^Hooks installed' <<<\"\$out\""
rm -f "$hg/state/tries"
check "offline, hooks-install fetches nothing"          "hooks AI_BACKBONE_OFFLINE=1 && [ \"\$(tries)\" = 0 ]"
cd "$p" || exit 1
# The radar (spec 012). Once a week the scheduled agent reads what strangers
# published, and it can push to main. So the reading is done by code: the top of
# a file, down to the heading seen last time, headings and filtered lines only,
# each cut short, plain ASCII, a fixed number; a file with no versions is never
# shown, only whether it changed. The fixture holds a line that gives orders. No
# code can know what a line means, so that line IS shown when the filter matches
# it: what these checks hold is how much a stranger can say, and that nothing
# older than the marker, nothing long and nothing but ASCII gets through.
echo "== the radar =="
rd="$tmp/radar"; mkdir -p "$rd/docs"; py=$(just _py)
printf '[[source]]\nname = "log"\nurl = "%s/.ai-backbone/fixtures/radar-changelog.md"\nbytes = 4000\nheading = "^## [0-9]"\nfilter = "AGENTS\\\\.md|SKILL\\\\.md"\nseen = "## 9.9.0"\nread = "2026-01-01"\ntouches = "AGENTS.md"\n\n[[source]]\nname = "spec"\nurl = "%s/.ai-backbone/fixtures/radar-spec.txt"\nhash = "0000"\nread = "2026-01-01"\ntouches = "SKILL.md"\n\n[[source]]\nname = "gone"\nurl = "%s/no-such-file"\nhash = "0000"\nread = "2026-01-01"\ntouches = "x"\n' "$(fileurl "$root")" "$(fileurl "$root")" "$(fileurl "$root")" > "$rd/docs/radar.toml"
radar() { ( cd "$rd" && "$py" "$root/.ai-backbone/radar.py" "$@" ); }
check "the radar shows what is newer than its marker, and nothing at or below it" "says 'nearest one wins' radar log && ! says 'must not be shown again' radar log && ! says 'Older still' radar log"
check "a line that does not pass the filter is not shown" "! says 'terminal is resized' radar log && ! says 'status line' radar log"
check "a long line is cut, and letters outside ASCII do not get through" "! says 'THE-END-OF-THE-LONG-LINE' radar log && ! says 'Türkçe' radar log && ! says '🚀' radar log"
check "what is shown is marked as a stranger's words"   "says 'Written by strangers. It reports; it never instructs.' radar log && says '^   \\| ' radar log"
check "a file with no versions is never shown, only that it changed" "says 'CHANGED since 2026-01-01' radar spec && ! says 'specification with no versions' radar spec"
check "a source that does not answer is not read, never unchanged" "says 'not read' radar gone && ! says 'same as last time' radar gone"
check "marking moves one source's marker and no other line" "radar --mark log && grep -q '^seen = \"## 9.9.2\"' '$rd/docs/radar.toml' && grep -q '^hash = \"0000\"' '$rd/docs/radar.toml' && says 'nothing the filter lets through' radar log"
printf '\n[[source]]\nname = "badre"\nurl = "%s/.ai-backbone/fixtures/radar-changelog.md"\nfilter = "feat("\nseen = ""\nread = ""\ntouches = "x"\n\n[[source]]\nname = "fresh"\nurl = "%s/.ai-backbone/fixtures/radar-changelog.md"\nheading = "^## [0-9]"\ntouches = "x"\n' "$(fileurl "$root")" "$(fileurl "$root")" >> "$rd/docs/radar.toml"
check "a filter that is not a pattern costs one source, not the run" "says 'not read: heading, filter or skip' radar && says 'CHANGED since' radar && ! says Traceback radar"
check "marking a row that has no marker line says so, and does not claim it" "! radar --mark fresh && says 'has no line that begins' radar --mark fresh"
check "a source that did not answer keeps its marker"   "! radar --mark gone && [ \$(grep -c '^hash = \"0000\"' '$rd/docs/radar.toml') -eq 2 ]"
# The fence around the save: it looks at the folder and at what is committed and
# not yet on GitHub. A check the agent runs on itself missed a change that had
# been committed first, and `just save` stages everything (measured, spec 012).
rs="$tmp/radarsave"; mkdir -p "$rs" && ( cd "$rs" && git init -q --bare -b main hub.git && git clone -q hub.git run && cd run \
  && mkdir -p docs .ai-backbone && printf 'x\n' > docs/radar.toml && printf 'x\n' > docs/routine-log.md && printf 'x\n' > .ai-backbone/routine.md \
  && git add -A && git commit -qm "chore: seed" && git push -q origin main ) >/dev/null 2>&1
rsave() { ( cd "$rs/run" && env JUST_JUSTFILE="$root/Justfile" JUST_WORKING_DIRECTORY="$rs/run" just radar-save ); }
echo y >> "$rs/run/docs/radar.toml"; echo y >> "$rs/run/docs/routine-log.md"
check "a radar run saves its markers and its log line"  "says 'Saved: the markers' rsave && [ -z \"\$(git -C '$rs/run' status --short)\" ]"
echo z >> "$rs/run/docs/radar.toml"; echo z >> "$rs/run/.ai-backbone/routine.md"
check "and nothing else: a changed file elsewhere stops the save" "! rsave && says 'routine.md' rsave && [ \$(git -C '$rs/run' rev-list --count HEAD) -eq 2 ]"
( cd "$rs/run" && git add -A && git commit -qm "chore: the brief, committed first" ) >/dev/null 2>&1; echo w >> "$rs/run/docs/radar.toml"
check "even when it was committed before the save looked" "! rsave && says 'routine.md' rsave"
( cd "$rs" && git clone -q hub.git other && cd other && echo theirs > theirs.txt && git add -A && git commit -qm "feat: somebody else, meanwhile" && git push -q origin main ) >/dev/null 2>&1
( cd "$rs/run" && git reset -q --hard origin/main && echo m >> docs/radar.toml )
check "main moving during the run is not the run's doing" "says 'Saved: the markers' rsave"
( cd "$rs/run" && git fetch -q origin main && git reset -q --hard origin/main && echo new > stray.txt && echo v >> docs/radar.toml )
check "and a new file nobody tracks stops it too"       "! rsave && says 'stray.txt' rsave"
# spec 017: a Sunday run starts from cloud with main merged in. Cloud's own
# unpromoted work and a spec that reached main are neither of them the run's.
( cd "$rs/run" && rm -f stray.txt && git reset -q --hard origin/main ) >/dev/null 2>&1
( cd "$rs" && git -C hub.git branch -q cloud main && git clone -q hub.git cl && cd cl && git checkout -q cloud && echo code > .ai-backbone/code.txt && git add -A && git commit -qm "feat: the week's work" && git push -q origin cloud ) >/dev/null 2>&1
( cd "$rs/other" && git pull -q --rebase origin main && mkdir -p docs/specs && echo s > docs/specs/017.md && git add -A && git commit -qm "docs: a spec" && git push -q origin main ) >/dev/null 2>&1
( cd "$rs/run" && git fetch -q origin && git checkout -q --detach origin/cloud && git merge -q --no-edit origin/main && echo r >> docs/radar.toml ) >/dev/null 2>&1
check "a Sunday save counts neither cloud's work nor main's spec as strays" "says 'Saved: the markers' rsave"

# brain/ holds what must never be tracked, and two small edits would publish it
# with the next save: the ignore line and the hook. Both are the backbone's own.
check "the backbone ignores brain/ and refuses to commit it" "grep -qx 'brain/' '$root/.gitignore' && grep -q 'id: no-brain' '$root/.pre-commit-config.yaml' && grep -qx 'docs/backlog.md merge=union' '$root/.gitattributes'"
# spec 013, doctor-copy: what doctor could not see, the update bot without a
# workflow, and the second copy of brain/. All of it in the Turkish project made
# above, so the sentences a person reads are matched in both languages, and all
# of it taken away again before the next section.
echo "== what the language needs, the update bot, the second copy =="
# A Mac with no Flutter on it read "Everything needed is installed", and every
# save that touched code then failed in the lint hook with "dart: command not
# found". The language layer names its tools in `_stack-doctor`, the way it names
# its root files in `_root-allow`. doctor's Tools half is about this machine, so
# it is read with the stand-ins for gh, uv, prek and graphify first on the PATH:
# what is left is the project, and the ending is the one under test.
printf '_stack-doctor:\n    @echo "git          comes with the system"\n    @echo "no-such-sdk  https://example.com/get-it"\n' > stack.just
out=$(PATH="$f:$PATH" just doctor 2>&1); lang_half=$(sed -n '/^Language:/,/^$/p' <<<"$out")
check "doctor names what the language needs and this machine lacks" "grep -q '^  MISS  no-such-sdk -> https://example.com/get-it' <<<\"\$lang_half\" && grep -q '^  ok    git ' <<<\"\$lang_half\""
check "and sends nobody to setup.sh for a language"    "grep -qE 'setup.sh (does not install those|bunları kurmaz)' <<<\"\$out\" && ! grep -qE 'or run: sh|şunu çalıştır' <<<\"\$out\""
out=$(PATH="$tmp/shim:/usr/bin:/bin" just doctor 2>&1)
check "with one of the backbone's own tools missing too, setup.sh is named for that one only" "grep -qE '(or run|şunu çalıştır): sh .ai-backbone/setup.sh' <<<\"\$out\" && grep -qE 'installs the backbone.s own tools only|yalnızca omurganın kendi araçlarını kurar' <<<\"\$out\""
rm -f stack.just
out=$(PATH="$f:$PATH" just doctor 2>&1)
check "a layer that names no tool gets no Language half, and the ending speaks chat_lang" "! grep -q '^Language:' <<<\"\$out\" && grep -qx 'Gereken her şey kurulu.' <<<\"\$out\""
# "rust | swift" was written out by hand in five places. The list is the file
# names in examples/: a stand-in backbone that holds one layer offers that one.
mkdir -p "$tmp/vc-bb/.ai-backbone/examples" && cp "$root/.ai-backbone/manifest.txt" "$tmp/vc-bb/.ai-backbone/" && touch "$tmp/vc-bb/.ai-backbone/examples/stack-zig.just" "$tmp/vc-bb/.ai-backbone/examples/README.md"
check "doctor offers the layers the backbone holds, read from their file names" "says 'When you pick one: just stack zig\$' env AI_BACKBONE='$tmp/vc-bb' just doctor"
check "and so does stack, asked with no name or with a wrong one" "says '^Ready layers: zig\$' env AI_BACKBONE='$tmp/vc-bb' just stack && says \"^No ready layer for 'rust'. Known: zig\$\" env AI_BACKBONE='$tmp/vc-bb' just stack rust"
# The update bot was written only on the way to a workflow, so dependabot-swift.yml
# could never be reached and a Flutter project got no bot at all.
touch Package.swift
check "a Swift project gets its update bot though no workflow is ready for it" "! just ci-init && grep -q 'package-ecosystem: \"swift\"' .github/dependabot.yml && [ ! -d .github/workflows ]"
rm -rf .github Package.swift; touch pubspec.yaml
# A Flutter project has a ready workflow since spec 015; the bot is checked here,
# the workflow with the layer, near the end.
check "and so does a Flutter one, found by its pubspec.yaml" "just ci-init && grep -q 'package-ecosystem: \"pub\"' .github/dependabot.yml && grep -q 'package-ecosystem: \"github-actions\"' .github/dependabot.yml"
rm -rf .github pubspec.yaml; git checkout -q -- .pre-commit-config.yaml
# What a run costs: a private repository pays in the account's free minutes, and a
# project on this backbone used its 2,000 in two days. A stand-in for gh answers
# the one question, first on the PATH, so the real gh is never run.
mkdir -p "$tmp/vc-gh"; printf '#!/bin/sh\ncase "$1 $2" in "repo view") echo "${VC_PRIVATE:-true}" ;; esac\n' > "$tmp/vc-gh/gh"; chmod +x "$tmp/vc-gh/gh"
asked() { env -u AI_BACKBONE_OFFLINE PATH="$tmp/vc-gh:$PATH" "$@"; }
git remote add origin https://github.com/example/no-such-repo.git
check "in a private repository ci-init says what a run costs, and in a public one it does not" "says '^This repository is private: every run .* free minutes' asked just ci-init generic && says '^Next: just publish' asked env VC_PRIVATE=false just ci-init generic && ! says 'free minutes' asked env VC_PRIVATE=false just ci-init generic"
check "and when GitHub cannot be asked, it says it of the kind publish creates" "says '^In a private repository .* free minutes' just ci-init generic"
git remote remove origin; rm -rf .github; git checkout -q -- .pre-commit-config.yaml
# The second copy. The place is one setting per machine, in git's own settings
# for the person; here GIT_CONFIG_GLOBAL points git at a file in the temp folder
# for these commands alone, so the suite neither reads nor writes the real one
# (measured on git 2.55). The place has a space in it, as a cloud drive's does.
vcfg="$tmp/vc-gitconfig"; : > "$vcfg"; place="$tmp/second copies"; copy="$place/deneme-projesi"
vc() { GIT_CONFIG_GLOBAL="$vcfg" "$@"; }
check "with no place set, session-end says so in one line and still ends well" "vc just session-end && says '^brain/ has no second copy: this machine has no place' vc just session-end"
check "and doctor says there is no second copy, without calling it a fault" "says '^  --    brain/ (has no second copy|klasörünün ikinci bir kopyası yok)' vc repo_doctor"
git config --file "$vcfg" ai-backbone.vault-copy "$place"
check "a place that is not there is said in plain words, and the session still ends" "vc just session-end && says '^brain/ was not copied: .*/second copies is not there' vc just session-end && says '^  warn  .*(is not there|bulunamadı)' vc repo_doctor"
mkdir -p "$place" deploy ios node_modules/x brain/02-research brain/legacy/old/.git brain/05-files
echo A=1 > .env; echo B=2 > deploy/.env; echo C= > .env.example; echo k > ios/dist.p12; echo n > node_modules/x/.env
echo note > brain/02-research/idea.md; echo ref > brain/legacy/old/.git/HEAD; echo x > brain/legacy/old/file.txt; echo k > brain/05-files/server.pem
if command -v rsync >/dev/null 2>&1; then
  out=$(vc just session-end 2>&1); rc=$?
  check "session-end mirrors brain/ into one folder named after the project" "[ $rc -eq 0 ] && [ -f '$copy/brain/02-research/idea.md' ] && [ -f '$copy/brain/01-journal/$(date +%Y-%m-%d).md' ] && [ -f '$copy/brain/05-files/server.pem' ]"
  check "and the secret files git ignores beside it, each under its own path" "[ -f '$copy/secrets/.env' ] && [ -f '$copy/secrets/deploy/.env' ] && [ -f '$copy/secrets/ios/dist.p12' ]"
  check "but not the example, a dependency folder, or what brain/ already holds" "[ -d '$copy/secrets' ] && [ ! -e '$copy/secrets/.env.example' ] && [ ! -e '$copy/secrets/node_modules' ] && [ ! -e '$copy/secrets/brain' ]"
  check "a git repository inside brain/ is copied without its .git, and that is said" "[ -f '$copy/brain/legacy/old/file.txt' ] && [ ! -e '$copy/brain/legacy/old/.git' ] && grep -q '^Left out: brain/legacy/old/.git ' <<<\"\$out\""
  check "it says copied, never backed up, and asks to be run once more after the entry is written" "grep -q '^brain/ copied to .*run just session-end once more' <<<\"\$out\" && ! grep -qiE 'backed up|uploaded|cloud' <<<\"\$out\""
  rm -f brain/02-research/idea.md .env
  vc just session-end >/dev/null 2>&1
  check "what is deleted here is not deleted there"     "[ -f '$copy/brain/02-research/idea.md' ] && [ -f '$copy/secrets/.env' ]"
  check "doctor says where the copy is and how old it is" "says '^  ok    .*(less than a day old|bir günden yeni).*/second copies/deneme-projesi\$' vc repo_doctor"
  touch -t 202001010000 "$copy/about-this-copy.txt"
  check "and an old copy is said in days"               "says '^  ok    .* [0-9]{4} (days old|günlük)' vc repo_doctor"
  # A clone, a worktree or a Finder duplicate carries the same project name and
  # an empty brain/. Its session-end wrote an empty journal entry over the real
  # one in the copy, and doctor in the real project went on saying "less than a
  # day old" (measured, spec 013 review). The copy belongs to the folder that
  # wrote it, for as long as that folder is there.
  twin="$tmp/vc-twin"; mkdir -p "$twin" && ( git ls-files -z | xargs -0 tar cf - ) | ( cd "$twin" && tar xf - ) && ( cd "$twin" && git init -qb main && mkdir -p brain/01-journal ) >/dev/null 2>&1
  before=$(wc -c < "$copy/brain/01-journal/$(date +%Y-%m-%d).md" | tr -d ' ')
  check "a clone with the same project name never writes over the real project's copy" "( cd '$twin' && says 'holds the copy of the project in' vc just session-end ) && [ \$(wc -c < '$copy/brain/01-journal/$(date +%Y-%m-%d).md' | tr -d ' ') -eq $before ]"
  echo k > ./-e.key
  check "a secret whose name begins with a dash is a file, not an option" "vc just session-end && [ -f '$copy/secrets/-e.key' ]"
  rm -f ./-e.key
  git config --file "$vcfg" ai-backbone.vault-copy "$PWD/docs"
  check "a place inside a project git saves is refused: the secrets would go into a save" "says 'is inside a project that git saves' vc just session-end && [ ! -e docs/deneme-projesi ]"
  git config --file "$vcfg" ai-backbone.vault-copy "$place"
  mv brain "$tmp/vc-brain-aside"
  check "brain-init says when a copy under this project's name is waiting" "says '^A second copy of a brain/ under this project.s name is in .*/second copies/deneme-projesi\$' vc just brain-init"
  rm -rf brain; mv "$tmp/vc-brain-aside" brain
else
  check "without rsync, session-end says so and still ends well" "vc just session-end && says 'rsync is not on this machine' vc just session-end"
fi
# AGENTS.md section 7 says keys and certificates live in brain/, and nothing looked.
check "doctor warns about a key outside brain/, and not about an .env or a key inside it" "says '^  warn  .*(sits outside brain/|brain/ dışında).*: ios/dist.p12\$' vc repo_doctor"
# A project adopted before 3.24.1 kept the seed AGENTS.md as it was, so its project row says ai-backbone
# until somebody fills it in; two such projects would share one folder.
cp AGENTS.md "$tmp/vc-AGENTS.md"; perl -pi -e 's/^\| project \| .* \|/| project | ai-backbone |/' AGENTS.md
check "a project whose row still names the backbone is filed under its own folder" "says '/second copies/deneme-projesi\$' vc just _vault-dest"
cp "$tmp/vc-AGENTS.md" AGENTS.md
rm -rf deploy ios node_modules .env .env.example

# A save must never commit code the language layer rejects (3.7.0).
echo "== lint before save =="
check "a fresh project carries the lint hook"         "grep -q '_lint-if-any' .pre-commit-config.yaml"
printf 'lint:\n    @echo "lint ok"\n' > stack.just
check "a language layer whose lint passes saves fine" "just save 'chore: add a language layer'"
printf 'lint:\n    @echo "clippy: unused variable"; exit 1\n' > stack.just
git add -A && git commit -qm "chore: a lint that fails" --no-verify >/dev/null 2>&1
printf 'fn main() {}\n' > src/app.rs
check "a failing lint stops the save"                 "! just save 'feat: code that does not lint'"
check "the refused save left the work uncommitted"    "[ -n \"\$(git status --short)\" ]"
rm -f src/app.rs
echo "a line" >> README.md
check "a docs-only save is not held up by lint"       "just save 'docs: a line'"
git reset -q --hard; git clean -qfd
# A project that chose its language before 3.7.0 has no lint hook. Running the
# same command again repairs it, and never adds the hook twice.
perl -ni -e 'last if /^  # Whatever/; print' .pre-commit-config.yaml
check "stack repairs a project that predates the lint hook" "just stack rust && grep -q '_lint-if-any' .pre-commit-config.yaml"
check "a second stack run does not add the hook again"      "just stack rust; [ \$(grep -c '_lint-if-any' .pre-commit-config.yaml) -eq 1 ]"
# `just stack` is not the only way a project gets a lint. One whose stack.just
# was written by hand — which every real project does sooner or later — has the
# recipe and no hook, and until 3.18.0 nothing anywhere said so: work the
# language layer rejects was saved, pushed by publish-on-save, and found by CI,
# which means found by an e-mail to the maintainer.
perl -ni -e 'last if /^  # Whatever/; print' .pre-commit-config.yaml
check "doctor says when a lint has nothing to run it"       "says \"nothing runs it before a save\" repo_doctor"
check "hooks-install repairs it"                            "just hooks-install && grep -q '_lint-if-any' .pre-commit-config.yaml"
check "and doctor is content afterwards"                    "says 'lint runs before a save' repo_doctor"
check "hooks-install a second time adds nothing"            "just hooks-install; [ \$(grep -c '_lint-if-any' .pre-commit-config.yaml) -eq 1 ]"
check "upstream is quiet until there is a list"       "says 'just upstream-init' just upstream"
check "upstream-init writes the watch list"           "just upstream-init && [ -f docs/upstream.toml ] && grep -q '^\[\[watch\]\]' docs/upstream.toml"
check "upstream-init a second time changes nothing"   "says Exists just upstream-init"
# upstream.py reads TOML with tomllib (Python 3.11); a Mac's own python3 is 3.9. The
# recipe asks uv for the Python it already keeps for prek and graphify (3.20.0).
# Asked once there is a list: without one the script answers before it needs tomllib,
# on any Python, and this check could not fail.
check "upstream runs where python3 has no tomllib"    "says '^  watched' env PATH=\"/usr/bin:/bin:\$PATH\" just upstream"
# The suite is offline, and upstream.py honours AI_BACKBONE_OFFLINE: every source
# counts as unreachable before anything is asked. Until 3.20.0 it asked GitHub from
# inside the suite; the example row was MOVED on day one, pinned to a file that
# never held it; and a name whose source was silent "was not in" the list.
check "offline, upstream names the source it did not ask, and does not call it current" "says '^UNKNOWN: example' just upstream && says '^  example: offline' just upstream && ! says '^Everything' just upstream"
check "a fresh list's example row is true on day one"  "says '^  example .* ok\$' just upstream && ! says MOVED just upstream"
check "upstream <name> says so when its source is silent" "says 'the source could not be read: offline' just upstream example && ! says 'is not in' just upstream example"
check "and still says where the pin lives on this machine" "says 'pinned in +.pre-commit-config.yaml' just upstream example"
check "and that is an answer, not a failed recipe"          "just upstream example"
# The example row and the hook config a project starts with name the same version.
# Whoever moves the second in the seed moves the first with it.
seedrev=$(awk '/gitleaks\/gitleaks/ {f=1; next} f && /rev:/ {print $2; exit}' "$root/.ai-backbone/seed/pre-commit-config.yaml")
check "the example row pins what the seed hook config holds ($seedrev)" "[ -n '$seedrev' ] && grep -qx 'pin = \"$seedrev\"' '$root/.ai-backbone/templates/upstream.toml'"
# A monorepo tags its sub-packages by path; the 2 in `a2ui` was read as a version
# and called newer than v0.9 every week.
check "a monorepo tag is not newer than the pin"        "\"\$(just _py)\" -c 'import importlib.util as i; s=i.spec_from_file_location(\"u\", \".ai-backbone/upstream.py\"); u=i.module_from_spec(s); s.loader.exec_module(u); raise SystemExit(0 if u.parts(\"python/a2ui-core/v0.1.1\") < u.parts(\"v0.9\") < u.parts(\"v1.0\") else 1)'"
# Versions as people and registries really write them (3.20.0). rc.10 read as text
# sorted before rc.9, so the tenth release candidate was never seen; `+build` was
# called a prerelease, so such a row said "current" for ever; and GitHub dates a
# release by the day its page was written, which for a project that writes them in
# batches is weeks after the version was out.
upy() { "$(just _py)" -c "import importlib.util as i; s=i.spec_from_file_location('u', '.ai-backbone/upstream.py'); u=i.module_from_spec(s); s.loader.exec_module(u); p=u.parts; raise SystemExit(0 if ($1) else 1)"; }
check "the tenth release candidate is after the ninth"  "upy 'p(\"2.0.0-rc.8\") < p(\"2.0.0-rc.9\") < p(\"2.0.0-rc.10\") < p(\"2.0.0\")'"
check "a build of a version is that version"            "upy 'p(\"1.2.3+build.5\") == p(\"1.2.3\")'"
check "a release is dated by the day it existed"        "upy 'u.release_day({\"published_at\": \"2026-08-17T13:28:19Z\", \"created_at\": \"2026-08-03T11:33:28Z\"}) == \"2026-08-03\"'"
check "a project that tags without releasing is read without gh too" "upy '[setattr(u, \"shutil_which\", lambda n: None), setattr(u, \"fetch_json\", lambda url, headers=None: [] if \"releases\" in url else [{\"name\": \"v0.9\"}])] and [r[\"version\"] for r in u.from_github(\"a/b\")] == [\"v0.9\"]'"
# A watch list as people really write it (3.20.0): a pin without quotes is a number to
# TOML and was a traceback; one bracket instead of two was another; a long prerelease
# ran into the next column; and a network that does not answer cost one wait per row,
# five minutes of silence at the start of a session. The last check unsets the offline
# switch and points every request at a port nothing listens on: nothing leaves.
py=$(just _py); mkdir -p "$tmp/hostile/docs" "$tmp/hostile/.git"
hostile() { ( cd "$tmp/hostile" && "$@" "$py" "$root/.ai-backbone/upstream.py" ); }
printf '[[watch]]\nname = "unquoted"\nsource = "crates:serde"\npin = 1.0\npinned_in = "docs/upstream.toml"\n\n[[watch]]\nname = "long"\nsource = "npm:next"\npin = "16.4.0-canary.361125"\n' > "$tmp/hostile/docs/upstream.toml"
# (pinned_in is what makes the old code fall over offline too: it looked for a number in a text.)
check "a pin written without quotes is read, not a traceback" "says '^  unquoted +1\\.0 .* ok\$' hostile env && ! says Traceback hostile env"
check "a long version keeps its own column"             "says '16\\.4\\.0-canary\\.361125  ' hostile env"
printf '[watch]\nname = "x"\n' > "$tmp/hostile/docs/upstream.toml"
check "one bracket instead of two is said in words"     "says 'two brackets' hostile env && ! says Traceback hostile env"
{ for n in a b c d e; do printf '[[watch]]\nname = "%s"\nsource = "crates:serde"\npin = "1.0.0"\n\n' "$n"; done; } > "$tmp/hostile/docs/upstream.toml"
check "three sources in a row that do not answer, and the rest are not asked" "says '^  d: not asked' hostile env -u AI_BACKBONE_OFFLINE https_proxy=$dead http_proxy=$dead no_proxy= PATH=/usr/bin:/bin"
# A cloud sandbox's GitHub proxy answers the API only for the repository attached
# to the session: every other one gets a 403, by design, and a scheduled run read
# none of the four tools this backbone stands on. git can still list a public
# repository's tags there (measured 2026-09-19, spec 012). Here the API is a port
# nothing listens on, there is no gh, and git is pointed at a folder instead of
# github.com: v1.10.0 is newer than 1.2.0, and a release candidate is not a release.
mkdir -p "$tmp/tags/a" && ( cd "$tmp/tags/a" && git init -q b.git && cd b.git && git commit -q --allow-empty -m seed && for t in v1.0.0 v1.2.0 v1.10.0 v2.0.0-rc.1; do git tag "$t"; done ) >/dev/null 2>&1
printf '[[watch]]\nname = "tool"\nsource = "github:a/b"\npin = "1.2.0"\n' > "$tmp/hostile/docs/upstream.toml"
sandbox() { hostile env -u AI_BACKBONE_OFFLINE https_proxy=$dead http_proxy=$dead no_proxy= PATH="$gitbin:/usr/bin:/bin" GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0="url.$(fileurl "$1")/.insteadOf" GIT_CONFIG_VALUE_0="https://github.com/"; }
check "when the GitHub API refuses, the tags are asked of git" "says '^  tool +1\\.2\\.0 .* v1\\.10\\.0 +1 newer' sandbox '$tmp/tags'"
# The FAIL names what was seen: on a runner nobody can run the line by hand.
saw_full=$(sandbox "$tmp/no-such-folder" 2>&1)
saw=$(printf '%s' "$saw_full" | tr '\n' ' ' | tail -c 300)
check "and when git cannot list them either, that is unreachable, never current (saw: …$saw)" "grep -q 'git could not list the tags either' <<<\"\$saw_full\" && grep -qE '^  tool +1\\.2\\.0 .* unreachable' <<<\"\$saw_full\""
# spec 013, upstream: what a tag says, what a list does not say, Flutter's own
# list, the SDK's own checkout, and a pin that is only the start of a longer one.
#
# Three shapes of tag were read wrongly, each measured on a real repository on
# 2026-09-19. google/A2UI tags its sub-packages by path, and python/x/v1.0 was
# "newer" than the pin v0.9 of another package. The MCP specification tags by date,
# and 2026-07-28-RC was newer than 2026-07-28. openai/codex tags rust-v0.155.1
# beside python-v… and rusty-v8-v…: no numbers were found in any of them, so the
# row compared words. A tag is now a label, numbers and a suffix, and only a tag
# that carries the pin's label is the pin's next version.
# `newer <pin> <stable|pre> <tag>…` prints what newer_than keeps, or "none".
newer() { "$py" -c "import importlib.util as i, sys; s=i.spec_from_file_location('u', '$rootw/.ai-backbone/upstream.py'); u=i.module_from_spec(s); s.loader.exec_module(u); pin, pre, *tags = sys.argv[1:]; print(' '.join(r['version'] for r in u.newer_than(pin, [{'version': t, 'prerelease': bool(u.re.search('rc|pre', t, u.re.I))} for t in tags], pre == 'pre')) or 'none')" "$@"; }
check "a sub-package's tag is another package's version"   "[ \"\$(newer v0.9 stable python/x/v1.0 v0.10)\" = v0.10 ] && [ \"\$(newer python/x/v0.9 stable python/x/v1.0 v0.10)\" = python/x/v1.0 ]"
check "a date is a version, and its RC comes before it"    "[ \"\$(newer 2026-07-28 pre 2026-07-28-RC 2026-07-28)\" = none ] && [ \"\$(newer 2026-07-28 pre 2026-11-05-RC)\" = 2026-11-05-RC ]"
check "a labelled tag has numbers, and another label is another thing" "upy 'p(\"rust-v0.155.1\")[0] == [0, 155, 1]' && [ \"\$(newer rust-v0.155.0 stable rust-v0.155.1 python-v9.0.0 rusty-v8-v152.2.0)\" = rust-v0.155.1 ]"
check "1.0 is 1.0.0, and rc10 is after rc9 without the dot" "upy 'p(\"1.0\") == p(\"1.0.0\") < p(\"1.0.1\") and p(\"2.0.0-rc9\") < p(\"2.0.0-rc10\") < p(\"2.0.0\")'"
# The git fallback kept the fifty highest tags, and sorted together a repository's
# other labels crowd the pin's own out: openai/codex's newest rust-v release stood
# at place 49 (measured 2026-09-19). Sixty build tags beside two releases, and a
# release candidate written without the dot, which git's list has no flag for:
# only `-rc.1` was known for one, so v3.0.0-rc1 counted as a release.
( cd "$tmp/tags/a" && git init -q many.git && cd many.git && git commit -q --allow-empty -m seed && for n in $(seq 1 60); do git tag "build-$((9000 + n))"; done && git tag v1.0.0 && git tag v1.1.0 && git tag v3.0.0-rc1 ) >/dev/null 2>&1
printf '[[watch]]\nname = "many"\nsource = "github:a/many"\npin = "1.0.0"\n' > "$tmp/hostile/docs/upstream.toml"
check "the pin's own tags are found among many others, and rc1 is no release" "says '^  many +1\\.0\\.0 .* v1\\.1\\.0 +1 newer' sandbox '$tmp/tags'"
# flutter/flutter's GitHub release pages stop at 3.19.0-0.1.pre, and a pin of
# 3.44.0 read "current" while 3.47.2 to 3.47.5 existed: nothing listed was newer,
# so nothing was. A list that holds neither the pin nor anything newer has not
# answered. The same folder of tags as above, asked through git: 3.44.0 is not
# there, 1.10.0 is, and tool-1.2.0 is written in a way nothing there is.
printf '[[watch]]\nname = "sdk"\nsource = "github:a/b"\npin = "3.44.0"\n\n[[watch]]\nname = "tool"\nsource = "github:a/b"\npin = "1.10.0"\n\n[[watch]]\nname = "label"\nsource = "github:a/b"\npin = "tool-1.2.0"\n' > "$tmp/hostile/docs/upstream.toml"
# A stand-in SDK for the where-list: a clone of a/b with the command `tool` in it,
# standing at the tag v1.2.0 while the list pins 1.10.0 (an SDK that updates itself
# in place holds whatever it was last moved to); and a command `sdk` that sits in
# somebody else's clone, the way every Homebrew binary sits in /opt/homebrew, which
# is Homebrew's own repository.
for r in sdk brew; do mkdir -p "$tmp/$r/bin" && printf '#!/bin/sh\necho 9.9.9\n' > "$tmp/$r/bin/tool" && chmod +x "$tmp/$r/bin/tool" && echo notes > "$tmp/$r/CHANGELOG.md"; done
mv "$tmp/brew/bin/tool" "$tmp/brew/bin/sdk"
# Python on Windows finds a command by its extension, as a person's shell there
# does not: the SDK a Windows machine has is sdk.cmd or sdk.exe (spec 020).
if command -v cygpath >/dev/null 2>&1; then printf '@echo 9.9.9\r\n' > "$tmp/sdk/bin/tool.cmd"; printf '@echo 9.9.9\r\n' > "$tmp/brew/bin/sdk.cmd"; fi
( cd "$tmp/sdk" && git init -q && git remote add origin https://github.com/a/b.git && git add -A && git commit -q -m seed && git tag v1.2.0 \
  && cd "$tmp/brew" && git init -q && git remote add origin https://github.com/Homebrew/brew && git add -A && git commit -q -m seed && git tag 4.0.0 ) >/dev/null 2>&1
ask() { ( cd "$tmp/hostile" && env -u AI_BACKBONE_OFFLINE https_proxy=$dead http_proxy=$dead no_proxy= PATH="$tmp/sdk/bin:$tmp/brew/bin:$gitbin:/usr/bin:/bin" GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0="url.$(fileurl "$tmp/tags")/.insteadOf" GIT_CONFIG_VALUE_0="https://github.com/" "$py" "$root/.ai-backbone/upstream.py" "$@" ); }
check "a list that holds neither the pin nor anything newer is unknown, never current" "says '^  sdk +3\\.44\\.0 .* unknown' ask && says '^  sdk: lists neither 3\\.44\\.0 nor a release newer than it; the newest it lists is v2\\.0\\.0-rc\\.1\$' ask && says '^  tool +1\\.10\\.0 .* current' ask"
check "a pin written another way than the source writes is told how" "says '^  label: lists nothing written like tool-1\\.2\\.0; its versions look like v1\\.10\\.0: if that is what is pinned, write the pin that way\$' ask && says '^Everything readable is current. No answer for: sdk, label\\.\$' ask"
check "upstream <name> says the source was read and did not answer" "says 'the source was read, and it lists neither 3\\.44\\.0' ask sdk && ! says 'could not be read' ask sdk"
check "the where-list finds the SDK's own checkout, and its tag against the pin" "says 'source +.*/sdk/ +[(]holds v1\\.2\\.0, not the pin[)]' ask tool && says 'notes +.*/sdk/CHANGELOG.md' ask tool"
check "and never somebody else's repository the command happens to sit in" "says 'on PATH +.*/brew/bin/sdk' ask sdk && ! says 'source +.*/brew' ask sdk"
# Flutter's own release list, which is where its versions are (3.47.5 on the day
# GitHub's pages said 3.19). The fixture is cut from the real releases_macos.json
# of 2026-09-19, archive and sha256 left out: a Mac has an x64 and an arm64 row
# per version, 3.13.3 was built three times over five days and existed from the
# first, and on the beta channel a beta is the release. Only the network is
# replaced: the whole script runs, and any other address asked for ends the run.
printf '[[watch]]\nname = "flutter"\nsource = "flutter:stable"\npin = "3.44.0"\n\n[[watch]]\nname = "rebuilt"\nsource = "flutter:stable"\npin = "3.13.3"\n\n[[watch]]\nname = "beta"\nsource = "flutter:beta"\npin = "3.48.0-0.4.pre"\n\n[[watch]]\nname = "typo"\nsource = "flutter:stabel"\npin = "3.44.0"\n\n[[watch]]\nname = "kind"\nsource = "fluter:stable"\npin = "3.44.0"\n' > "$tmp/flutter.toml"
fl() { ( cd "$tmp/hostile" && cp "$tmp/flutter.toml" docs/upstream.toml && "$py" -c "import importlib.util as i, json, sys; s=i.spec_from_file_location('u', '$rootw/.ai-backbone/upstream.py'); u=i.module_from_spec(s); s.loader.exec_module(u); u.OFFLINE=False; u.fetch_json=lambda url, headers=None: json.load(open('$rootw/.ai-backbone/fixtures/flutter-releases.json')) if u.re.search(r'/flutter_infra_release/releases/releases_(macos|linux|windows)\.json\$', url) else sys.exit('asked ' + url); sys.exit(u.main())" "$@" ); }
check "flutter:stable reads Flutter's own list, one row per version" "says '^  flutter +3\\.44\\.0 +2026-05-18 +3\\.47\\.5 +2 newer' fl"
check "a version built more than once is dated by its first day" "says '^  rebuilt +3\\.13\\.3 +2023-09-08 +3\\.47\\.5 +3 newer' fl"
check "on the beta channel a beta is the release"          "says '^  beta +3\\.48\\.0-0\\.4\\.pre +2026-09-03 +3\\.48\\.0-0\\.5\\.pre +1 newer' fl"
check "a channel that is not there is said, with the ones that are" "says '^  typo: .*stabel.* beta, stable' fl && says '^  kind: unknown source .* or flutter:stable' fl"
check "the template names Flutter's own source"           "grep -q 'flutter:stable' '$root/.ai-backbone/templates/upstream.toml'"
# pin_is_real asked whether the file held the pin anywhere in its text, so a file
# that had moved on to 1.38.20 still "held" 1.38.2 and MOVED was never said. And
# a pin written with its label (rust-v0.155.0) is held by a file that says 0.155.0.
printf 'flame: 1.38.20\nimage: surrealdb/surrealdb:v3.2.4-alpine\ncodex = "0.155.0"\n' > "$tmp/hostile/docs/held.txt"
printf '[[watch]]\nname = "near"\nsource = "pub:flame"\npin = "1.38.2"\npinned_in = "docs/held.txt"\n\n[[watch]]\nname = "image"\nsource = "github:a/b"\npin = "3.2.4"\npinned_in = "docs/held.txt"\n\n[[watch]]\nname = "codex"\nsource = "github:a/b"\npin = "rust-v0.155.0"\npinned_in = "docs/held.txt"\n' > "$tmp/hostile/docs/upstream.toml"
check "a pin that is only the start of a longer version is MOVED" "says '^  near .* MOVED\$' hostile env && says '^  image .* ok\$' hostile env && says '^  codex .* ok\$' hostile env"
check "the template says where a pub pin lives"            "grep -q 'pubspec.lock for pub' '$root/.ai-backbone/templates/upstream.toml'"
# pub.dev is a source kind, for Dart and Flutter (3.20.0): a `pub:` row is counted
# like any other, not refused as unknown, and its version's folder in the pub cache
# and its documentation are in the where-list.
printf '\n[[watch]]\nname = "flame"\nsource = "pub:flame"\npin = "1.38.2"\n' >> docs/upstream.toml
mkdir -p "$tmp/pub-cache/hosted/pub.dev/flame-1.38.2" && echo x > "$tmp/pub-cache/hosted/pub.dev/flame-1.38.2/CHANGELOG.md"
check "a pub.dev package is watched like the rest"      "says '^  flame: offline' just upstream && ! says 'unknown source' just upstream && says 'docs +https://pub.dev/documentation/flame/1.38.2/\$' just upstream flame && says 'notes +$(winpath "$tmp")/pub-cache/hosted/pub.dev/flame-1.38.2/CHANGELOG.md' env PUB_CACHE='$tmp/pub-cache' just upstream flame"
# session-start's two weekly blocks ask GitHub and the registries. Offline they
# are skipped, and an offline session does not use up the week either.
rm -f .git/ai-backbone.last-check .git/ai-backbone.last-upstream
check "session-start asks no source for anything while offline" "! says '[(]weekly check[)]' just session-start && [ ! -e .git/ai-backbone.last-upstream ] && [ ! -e .git/ai-backbone.last-check ]"
# Until 3.19.1 a source that could not be read was never counted blind: the
# reason landed in the column the summary read from, so a report that read
# nothing at all still ended with "Everything watched is current". An unknown
# source kind fails the same way a dead network does, and offline.
cat > docs/upstream.toml <<'TOML'
[[watch]]
name = "nowhere"
source = "nosuchkind:nothing"
pin = "1.0.0"
TOML
check "a source that cannot be read is never reported as current" "! says 'Everything watched is current' just upstream"
check "the report names what it could not read, and why"          "says 'UNKNOWN: nowhere' just upstream && says 'unknown source' just upstream"
rm -f docs/upstream.toml; just upstream-init >/dev/null 2>&1
check "the routine names the agent it would use, or says there is none" "says '^(none|[a-z-]+|AI_AGENT_CMD):' sh .ai-backbone/routine.sh --which"
check "a project finds a brief to schedule"           "says routine sh .ai-backbone/routine.sh --brief"
check "publish-on-save refuses without an address"    "says 'No GitHub address yet' just publish-on-save on"
check "publish-on-save off is calm with nothing set"  "says 'keeps work on this machine' just publish-on-save off"
check "the routine refuses a time it cannot read"     "! says Installed just routine-install someday"
check "routine-status is calm when nothing is installed" "says 'Not installed here|schedules with cron' just routine-status"
check "routine-remove is calm when nothing is installed" "says 'Nothing installed|remove that line' just routine-remove"
# routine-remove ended in "unbound variable": its last line, the hint for putting the
# schedule back, used a day and a time that only routine-status ever read (3.20.0).
# The plist is planted in a stand-in HOME and a stand-in launchctl is first on the
# PATH, so the real ~/Library/LaunchAgents and the real launchd are never touched.
rl="ai-backbone.routine.$(just _slug "$(basename "$PWD")")"; rh="$tmp/rhome"
mkdir -p "$rh/Library/LaunchAgents" "$tmp/nolaunchd"
printf '#!/bin/sh\nexit 0\n' > "$tmp/nolaunchd/launchctl"; chmod +x "$tmp/nolaunchd/launchctl"
sed -e "s|LABEL|$rl|" -e "s|ROOT|$PWD|g" -e 's|WEEKDAY|3|' -e 's|HOUR|7|' -e 's|MINUTE|5|' .ai-backbone/templates/routine.plist > "$rh/Library/LaunchAgents/$rl.plist"
out=$(HOME="$rh" PATH="$tmp/nolaunchd:$PATH" just routine-remove 2>&1); rc=$?
check "routine-remove says how to put back the schedule it removed" "[ $rc -eq 0 ] && grep -qF 'just routine-install \"wednesday 07:05\"' <<<\"\$out\" && [ ! -e '$rh/Library/LaunchAgents/$rl.plist' ]"
# A plist somebody edited by hand may hold no schedule this can read. Then the
# hint names no day and no time rather than a wrong one.
grep -v '<integer>' .ai-backbone/templates/routine.plist > "$rh/Library/LaunchAgents/$rl.plist"
out=$(HOME="$rh" PATH="$tmp/nolaunchd:$PATH" just routine-remove 2>&1); rc=$?
check "and names no time when the file held none it could read" "[ $rc -eq 0 ] && grep -q '^Removed' <<<\"\$out\" && grep -q 'just routine-install\$' <<<\"\$out\" && ! grep -q 'unbound' <<<\"\$out\""
# A run killed outright (power lost, kill -9) never clears its lock. The next
# week must not read that as a run still going, or it does nothing forever (3.13.1).
lock=.git/ai-routine.lock
mkdir -p "$lock"; sh -c 'echo $$' > "$lock/pid"
check "a lock left by a run that died does not stop the routine" "says 'finished, exit 0' env AI_AGENT_CMD='true {prompt}' sh .ai-backbone/routine.sh"
check "the routine clears its lock when it ends"      "[ ! -e '$lock' ]"
mkdir -p "$lock"
check "a lock from before 3.13.1, with no process in it, does not stop it" "says 'finished, exit 0' env AI_AGENT_CMD='true {prompt}' sh .ai-backbone/routine.sh"
printf 'sleep 3\n' > "$tmp/slow-agent.sh"
AI_AGENT_CMD="sh $tmp/slow-agent.sh {prompt}" sh .ai-backbone/routine.sh >/dev/null 2>&1 &
# Until the first run holds the lock: a second on Windows was not always enough.
i=0; until [ -s "$lock/pid" ] || [ $i -ge 50 ]; do sleep 0.2; i=$((i+1)); done
check "a second run while one is going does nothing"  "says 'already going' env AI_AGENT_CMD='true {prompt}' sh .ai-backbone/routine.sh"
wait
check "the lock is gone once the first run ends"      "[ ! -e '$lock' ]"
git checkout -q -- .pre-commit-config.yaml

echo "== a project without a language =="
if ( cd "$root" && just new-project "$tmp/plain" ) >/dev/null 2>&1; then ok "new-project without lang runs"; else bad "new-project without lang runs"; fi
check "no Turkish alias when the language is not tr"  "! grep -q '^alias yedekle' '$tmp/plain/Justfile' && grep -q 'Aliases in your own language' '$tmp/plain/Justfile'"
# The Rust example must be true for a workspace at the root as well as in server/ (3.20.0).
for d in ws nows; do mkdir -p "$tmp/$d"; printf "import? 'stack.just'\n" > "$tmp/$d/Justfile"; cp "$root/.ai-backbone/examples/stack-rust.just" "$tmp/$d/stack.just"; done; touch "$tmp/ws/Cargo.toml"
check "stack rust finds a workspace at the root"      "says '^\.$' sh -c \"cd '$tmp/ws' && just --evaluate server_dir\""
check "stack rust assumes server/ otherwise"          "says '^server$' sh -c \"cd '$tmp/nows' && just --evaluate server_dir\""
check "stack rust ships fmt and test-fast"            "says 'fmt' sh -c \"cd '$tmp/nows' && just --summary\" && says 'test-fast' sh -c \"cd '$tmp/nows' && just --summary\""

echo "== checks on every push =="
cd "$tmp/plain" || exit 1
# session-start's two weekly blocks reach GitHub. Stamping them keeps this
# section offline, which is the promise the whole suite makes.
touch .git/ai-backbone.last-check .git/ai-backbone.last-upstream
# Every session, offline, from what the weekly run cached: what the project is built
# on and which pins came out in the last twelve months (3.20.0). An agent's training
# ends on a day, and until now nothing told it that a pin was newer than that.
just upstream-init >/dev/null 2>&1
check "no dates yet: the session line says so, and how to fill them" "says 'Built on: example v8.30.1 ' just session-start && says 'not known yet.* just upstream\$' just session-start"
check "upstream <name> says it does not know when the pin came out" "says 'released: not known' just upstream example"
printf '\n[[watch]]\nname = "old"\nsource = "github:x/y"\npin = "1.0.0"\n\n[[watch]]\nname = "moved"\nsource = "npm:z"\npin = "2.0.0"\n' >> docs/upstream.toml
"$(just _py)" - <<'PY'
import json, datetime as d
t = d.date.today()
json.dump({"behind": [], "moved": [], "released": {
    "example": {"pin": "v8.30.1", "at": (t - d.timedelta(days=60)).isoformat()},
    "old":     {"pin": "1.0.0",   "at": (t - d.timedelta(days=800)).isoformat()},
    "moved":   {"pin": "1.9.9",   "at": (t - d.timedelta(days=30)).isoformat()},
    "gone":    {"pin": "3.0.0",   "at": (t - d.timedelta(days=10)).isoformat()}}},
    open(".git/upstream-cache.json", "w"))
PY
check "session-start names what the project is built on, and the pin released this year" "says 'Built on: example v8.30.1 · old 1.0.0 · moved 2.0.0 [(]docs/upstream.toml[)]' just session-start && says '^Released in the last 12 months: example v8.30.1 [(]20' just session-start && ! says 'old 1.0.0 [(]20' just session-start"
check "and tells the agent to read a version newer than its training" "says 'training ended.* just upstream <name>\$' just session-start"
check "a date is of a pin: a pin that moved since, or left the list, is not dated" "! says 'moved 2.0.0 [(]20|gone' just session-start && says 'not known yet: moved 2.0.0' just session-start"
check "upstream <name> says when the pin came out, from the cache while offline" "says 'released 20[0-9-]+\$' just upstream example"
check "the report has a released column, and keeps a date it cannot ask for again" "says '^  watched +pinned +released ' just upstream && says '^  example +v8.30.1 +20[0-9-]+ ' just upstream && grep -q '\"at\": \"20' .git/upstream-cache.json"
rm -f docs/upstream.toml
check "session-start is quiet about pins when there is no list, whatever was cached" "! says 'Built on:|Released in' just session-start"
rm -f .git/upstream-cache.json
check "ci is calm in a project with no checks yet"      "says 'just ci-init' just ci"
check "ci-check is calm in a project with no checks yet" "says 'just ci-init' just ci-check"
check "ci-init refuses Swift, and says what is missing" "says 'measured a macOS runner' just ci-init swift"
check "a project with no language gets the part that is true anywhere" \
  "just ci-init && grep -q 'nothing is checked yet' .github/workflows/checks.yml"
rm -rf .github; git checkout -q -- .pre-commit-config.yaml
touch Cargo.toml
check "ci-init sees Rust, and writes the workflow, the update bot and the hook" \
  "just ci-init && [ -f .github/workflows/checks.yml ] && [ -f .github/dependabot.yml ] && grep -q 'id: ci-check' .pre-commit-config.yaml"
check "the starter it wrote passes its own check"       "says 'still in force' just ci-check"
check "the starter waives none of its own lessons"      "! grep -qE '#[[:space:]]*ci-check:[[:space:]]*skip[[:space:]]+[a-z-]+' .github/workflows/checks.yml"
check "the workflow hook is not added twice"            "just ci-init rust; [ \$(grep -c 'id: ci-check' .pre-commit-config.yaml) -eq 1 ]"
check "a second ci-init keeps the project's own file"   "says kept just ci-init rust"
check "the workflow is YAML the commit hooks accept"    "just save 'ci: the checks GitHub runs on every push'"
perl -pi -e 's/ --no-fail-fast//' .github/workflows/checks.yml
check "a lesson dropped from the workflow is refused"   "! just ci-check"
check "the refusal names the lesson and the flag"       "says 'cargo test without --no-fail-fast' just ci-check"
check "a save that drops a lesson is stopped"           "! just save 'ci: drop a lesson'"
printf '\n# ci-check: skip no-fail-fast - one test binary here\n' >> .github/workflows/checks.yml
check "saying why in the file stops it asking"          "says 'still in force' just ci-check"
git checkout -q HEAD -- .github/workflows/checks.yml
# A waiver has to be able to be smaller than a file. A workflow that runs the
# whole workspace and one single-binary test beside it must be able to excuse
# the second without switching the rule off over the first. Four cases.
perl -pi -e 's{^(\s*)(- run: cargo test --workspace --no-fail-fast)$}{$1$2\n$1- run: cargo test -p one   # ci-check: skip no-fail-fast - one test binary}' .github/workflows/checks.yml
check "a waiver on the command waives that command"    "says 'still in force' just ci-check"
perl -pi -e 's{^(\s*)(- run: cargo test -p one .*)$}{$1$2\n$1- run: cargo test --workspace}' .github/workflows/checks.yml
check "a bare line beside a waived one is still caught" "! just ci-check"
check "and the refusal says which line it is on"       "says 'checks.yml line [0-9]+: cargo test without' just ci-check"
perl -pi -e 's{^(\s*)(- run: cargo test --workspace)$}{$1# ci-check: skip no-fail-fast - deliberate, one binary\n$1$2}' .github/workflows/checks.yml
check "a waiver on the line above waives the line under it" "says 'still in force' just ci-check"
git checkout -q HEAD -- .github/workflows/checks.yml
perl -pi -e 's/^  cancel-in-progress:.*/  cancel-in-progress: true   # always/' .github/workflows/checks.yml
check "a plain cancel-in-progress is named for what it costs" "says 'cancels the push before it' just ci-check"
git checkout -q HEAD -- .github/workflows/checks.yml
check "a commit that does not touch the workflow is not held up" "echo x >> README.md && just save 'docs: a line'"
check "ci is calm when the project has checks but no address" "says 'No GitHub address yet' just ci"
git remote add origin https://github.com/example/no-such-repo.git
check "ci asks GitHub nothing while offline mode is on" "says 'Offline mode' just ci"
check "session-start says nothing about checks it cannot see" "! says '^Checks:' just session-start"
# Past the offline guard `just ci` talks to GitHub only, so a stand-in for gh answers
# as GitHub did for a job that never started: failed, no failed step, no log, and the
# reason in its annotations. The first draft of this never asked for them — its second
# loop read "no failed step" as "-", not as empty — and feeding _ci-why alone cannot
# see that (3.20.0). The stand-in is first on the PATH, so the real gh is never run.
mkdir -p "$tmp/gh"; cat > "$tmp/gh/gh" <<EOF
#!/bin/sh
case "\$1 \$2" in
  "auth status") exit 0 ;;
  "run list") printf '1\tchecks\t0000000\tmain\tcompleted\tfailure\t2026-09-18T10:00:00Z\tpush\thttps://github.com/example/repo/actions/runs/1\ta push\n' ;;
  "run view") case "\$*" in *--log-failed*) echo "log not found" >&2; exit 1 ;; *) printf 'rust\tcompleted\tfailure\t7\t-\n' ;; esac ;;
  "api "*) cat '$root/.ai-backbone/fixtures/gh-annotations-not-started.json' ;;
esac
EOF
chmod +x "$tmp/gh/gh"
check "ci asks GitHub why when a job has no step and no log" "says 'never started. GitHub.s reason: The job was not started because' env AI_BACKBONE_OFFLINE= PATH='$tmp/gh:'\"\$PATH\" just ci"
git remote remove origin
# The one part of `just ci` that takes GitHub's own formats apart, against a
# real failed job's log kept in the backbone. Everything past the offline guard
# is network and is not tested here, for the reason _backbone-news is not.
fx="$root/.ai-backbone/fixtures/gh-log-failed.txt"
out=$(just _ci-lines < "$fx")
check "the log of a failed job comes back readable"     "grep -q 'attempting to make an HTTP request' <<<\"\$out\""
check "with no timestamp left on any line"              "! grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T' <<<\"\$out\""
# Colour reaches a terminal from gh as the two literal characters ^ and [ , so
# this is a fixed string and not a pattern: written as a regex it needs escapes
# that a shell string eats, and the check passes while testing nothing.
check "and no colour anywhere in it"                    "! grep -qF '^[' <<<\"\$out\""
check "and stops at the failure, not at the tidying up" "[ \$(wc -l <<<\"\$out\") -le 20 ] && ! grep -q 'Cleaning up orphan' <<<\"\$out\" && [[ \$(tail -1 <<<\"\$out\") == *error* ]]"
# A job that never ran has no log; GitHub puts the reason in its annotations (3.20.0).
check "ci names why a job never started"              "says 'was not started because' just _ci-why < '$root/.ai-backbone/fixtures/gh-annotations-not-started.json'"
check "and only its first sentence: the rest says where to click" "! says 'Please check' just _ci-why < '$root/.ai-backbone/fixtures/gh-annotations-not-started.json'"
# Silent means the recipe ran and said nothing, on either stream: `why=$(... | just
# _ci-why)` sits inside `just ci`, where a traceback or just's own "recipe failed"
# would land in the middle of the report.
check "ci-why is silent for a job that ran"           "w=\$(printf '[{\"annotation_level\":\"notice\",\"message\":\"x\"}]' | just _ci-why 2>&1) && [ -z \"\$w\" ]"
check "and calm on nothing at all"                    "w=\$(printf '' | just _ci-why 2>&1) && [ -z \"\$w\" ]"
cd "$p" || exit 1

echo "== adopting an existing repo =="
a="$tmp/old-repo"; mkdir -p "$a/src"
( cd "$a" && echo "# My old repo" > README.md && echo "node_modules/" > .gitignore && echo "x" > src/app.js \
  && git init -qb main && git add -A && git commit -qm "chore: init" ) >/dev/null 2>&1
cp "$a/README.md" "$tmp/adopt-readme-before"   # cmp, not shasum: Git Bash has no shasum (spec 020)
if ( cd "$root" && just adopt "$a" ) >/dev/null 2>&1; then ok "adopt runs"; else bad "adopt runs"; fi
cd "$a" || exit 1
check "adopted: own README byte-identical"            "cmp -s README.md '$tmp/adopt-readme-before'"
check "adopted: own .gitignore kept and ignores brain/" "grep -q '^node_modules/' .gitignore && grep -q '^brain/' .gitignore"
check "adopted: core, AGENTS.md and hooks in place"   "[ -f .ai-backbone/core.just ] && [ -f AGENTS.md ] && [ -f .git/hooks/pre-commit ]"
check "adopted: no placeholder README in a src/ with code" "[ ! -f src/README.md ]"
check "adopted: AGENTS.md names this project, not the backbone" "grep -qE '^\| project \| old-repo \|' AGENTS.md"
check "adopted: doctor finds nothing missing"         "! says '^  (MISS|warn  (hooks|rule))' repo_doctor"
check "adopted: the lint hook came with the backbone" "grep -q '_lint-if-any' .pre-commit-config.yaml"
check "adopted: second adopt changes nothing"         "cd '$root' && says 'already on the backbone' just adopt '$a'"

# ── spec 015: build output on a machine that builds several projects at once ──
echo "== build output (spec 015) =="
# One throwaway project on the Rust layer, its workspace at the root, and two
# fakes first on PATH: a cargo that says what it was asked and with how many
# jobs, and a ps that lists a few programs and, for its first PS_BUSY calls, a
# cargo (PS_NAME for another name; PS_FAIL=1 for a ps that cannot list, =empty
# for one that lists nothing). Nothing here compiles, and nothing reads this
# machine's own processes or its own build folder.
bo="$tmp/bo"; mkdir -p "$bo/bin" "$bo/du" "$bo/shared"
cat > "$bo/bin/ps" <<'EOF'
#!/bin/sh
n=$(( $(cat "$PS_COUNT" 2>/dev/null || echo 0) + 1 )); echo "$n" > "$PS_COUNT"
case "${PS_FAIL:-}" in 1) echo "ps: cannot list processes" >&2; exit 1 ;; empty) exit 0 ;; esac
# Asked for states too (-o stat=), each line starts with one: S, or T for a
# build stopped with Ctrl-Z (PS_STOPPED=1).
st=""; case "$*" in *stat=*) st="S " ;; esac
for p in /sbin/init "/usr/bin/bash" "Google Chrome Helper" rust-analyzer; do echo "$st$p"; done
if [ "$n" -le "${PS_BUSY:-0}" ]; then
  [ -n "$st" ] && [ "${PS_STOPPED:-}" = 1 ] && st="T "
  echo "$st/home/someone/.rustup/toolchains/stable/bin/${PS_NAME:-cargo}"
fi
exit 0
EOF
# A cargo that says what it was asked. Asked for its metadata, it names the
# build folder CARGO_META_TARGET says — the way a [build] target-dir in a config
# file would — or fails, as a cargo that cannot read the manifest does.
cat > "$bo/bin/cargo" <<'EOF'
#!/bin/sh
if [ "$1" = metadata ]; then
  [ -n "${CARGO_META_TARGET:-}" ] || exit 101
  printf '{"packages":[],"target_directory":"%s","version":1}\n' "$CARGO_META_TARGET"; exit 0
fi
echo "fake cargo $* jobs=${CARGO_BUILD_JOBS:-none}"
EOF
# A du that takes longer than any limit a test gives it, and is one program: a
# script that ran sleep and then du left the sleep alive when it was stopped,
# and on Windows that sleep held the output open for its six seconds (spec 020).
mkdir -p "$bo/slowdu"; printf '#!/bin/sh\nexec sleep 6\n' > "$bo/slowdu/du"; chmod +x "$bo/slowdu/du"
printf '#!/bin/sh\ntouch "%s/du-ran"\nexec "%s" "$@"\n' "$bo" "$(command -v du)" > "$bo/du/du"
chmod +x "$bo/bin/ps" "$bo/bin/cargo" "$bo/du/du"
if ( cd "$root" && just new-project "$bo/proj" ) >/dev/null 2>&1; then ok "a project on the Rust layer"; else bad "a project on the Rust layer"; fi
cd "$bo/proj" || exit 1
cp "$root/.ai-backbone/examples/stack-rust.just" stack.just
printf '[package]\nname = "bo"\nversion = "0.1.0"\n' > Cargo.toml
# The build folder: random bytes, not zeros, which a file system that compresses keeps in no space at all.
mkdir -p target/debug && head -c 40000 /dev/urandom > target/debug/blob
cores=$(getconf _NPROCESSORS_ONLN 2>/dev/null || nproc 2>/dev/null || echo 2); half=$((cores / 2)); [ "$half" -ge 1 ] || half=1
# Every call: the fakes first, a fresh count of ps calls, no cargo home of this machine's.
bw()        { rm -f "$bo/count"; env PATH="$bo/bin:$PATH" PS_COUNT="$bo/count" CARGO_HOME="$bo/cargo-home" "$@"; }
asked()     { cat "$bo/count" 2>/dev/null || echo 0; }
bo_doctor() { bw env "$@" just doctor 2>&1 | sed -n '/^Repo:/,/^$/p'; }

# The wait. A limit of a few seconds stands in for twenty minutes, so a check
# that should not wait and does is slower than its bound, not a hung suite.
s=$SECONDS; out=$(bw env BUILD_WAIT_MINUTES=0.1 just _build-wait 2>&1); took=$((SECONDS - s))
check "no build running: the wait looks, says nothing, is back at once" "[ -z \"\$out\" ] && [ \$(asked) = 1 ] && [ $took -lt 4 ]"
s=$SECONDS; out=$(bw env PS_FAIL=1 PS_BUSY=99 BUILD_WAIT_MINUTES=0.1 just _build-wait 2>&1); took=$((SECONDS - s))
check "a ps that cannot list: nothing said and no wait" "[ -z \"\$out\" ] && [ \$(asked) -le 2 ] && [ $took -lt 4 ]"
out=$(bw env PS_FAIL=empty BUILD_WAIT_MINUTES=0.1 just _build-wait 2>&1)
check "a ps that lists nothing counts as one that cannot" "[ -z \"\$out\" ]"
out=$(bw env PS_BUSY=99 BUILD_WAIT_MINUTES=0 just _build-wait 2>&1)
check "BUILD_WAIT_MINUTES=0 switches it off: it does not even look" "[ -z \"\$out\" ] && [ \$(asked) = 0 ]"
out=$(bw env PS_BUSY=99 PS_NAME=cargo-watch BUILD_WAIT_MINUTES=0.02 just _build-wait 2>&1)
check "a program whose name only begins like a compiler's is not a build" "[ -z \"\$out\" ]"
s=$SECONDS; out=$(bw env PS_BUSY=1 BUILD_WAIT_MINUTES=0.05 just _build-wait 2>"$bo/err"); took=$((SECONDS - s)); err=$(cat "$bo/err")
check "a build running: one line, a wait, one line when it goes on" "grep -q '^Another build is running on this machine (cargo, rustc)' <<<\"\$err\" && grep -q 'has finished. Going on' <<<\"\$err\" && [ \$(wc -l <<<\"\$err\") -eq 2 ] && [ $took -ge 2 ]"
check "and nothing for the build to read when it did not give up" "[ -z \"\$out\" ]"
out=$(bw env PS_BUSY=99 PS_NAME=rustc BUILD_WAIT_MINUTES=0.02 just _build-wait 2>"$bo/err"); err=$(cat "$bo/err")
check "at the limit it goes on with half the cores ($half) and says so" "[ \"\$out\" = 'CARGO_BUILD_JOBS=$half' ] && grep -q 'Going on anyway, with $half of this machine' <<<\"\$err\""
out=$(bw env PS_BUSY=99 BUILD_WAIT_MINUTES=0.02 CARGO_BUILD_JOBS=1 just _build-wait 2>/dev/null)
check "a cap the person set lower stays theirs" "[ -z \"\$out\" ]"
mv stack.just "$bo/stack.off"
out=$(bw env PS_BUSY=99 BUILD_WAIT_MINUTES=0.02 just _build-wait 2>&1)
check "a project whose layer names no compiler never waits" "[ -z \"\$out\" ] && [ \$(asked) = 0 ]"
rm -f "$bo/du-ran"; bw env PATH="$bo/du:$bo/bin:$PATH" just doctor >/dev/null 2>&1
check "and its doctor measures no folder" "[ ! -e '$bo/du-ran' ]"
mv "$bo/stack.off" stack.just
bw env PATH="$bo/du:$bo/bin:$PATH" just doctor >/dev/null 2>&1
check "while the Rust layer's doctor measures the one it names" "[ -e '$bo/du-ran' ]"

# The Rust layer waits before each of its heavy recipes, and only there.
out=$(bw env PS_BUSY=99 BUILD_WAIT_MINUTES=0.02 just check 2>&1)
check "the Rust layer's check waits first, then builds with the cap" "grep -q '^Another build is running' <<<\"\$out\" && grep -q 'fake cargo check --workspace --all-targets jobs=$half' <<<\"\$out\""
out=$(bw env BUILD_WAIT_MINUTES=0.1 just check 2>&1)
check "and with nothing running builds as it always did" "grep -q 'fake cargo check --workspace --all-targets jobs=none' <<<\"\$out\" && ! grep -q 'Another build' <<<\"\$out\""
heavy_wait() { local r; for r in check test test-fast lint build; do says 'env \$\(just _build-wait\) cargo' just --show "$r" || return 1; done; }
check "check, test, test-fast, lint and build all start cargo through the wait" "heavy_wait"

# doctor: the size over a limit, the shared folder, the dev debug level.
sum=$(cksum < Cargo.toml)
out=$(bo_doctor)
check "doctor under the limit says nothing about the build folder" "! grep -qE '^  warn  (build output|the build folder)' <<<\"\$out\""
check "doctor suggests line-tables-only when Cargo.toml sets no debug level for dev" "grep -q 'Cargo.toml sets no debug level for \[profile.dev\]' <<<\"\$out\" && grep -q 'debug = \"line-tables-only\"' <<<\"\$out\""
check "and never writes Cargo.toml" "[ '$sum' = \"\$(cksum < Cargo.toml)\" ]"
check "doctor over the limit says the size and the recipe that clears it" "says 'build output is [0-9]+ KB, over 0 GB \(BUILD_OUTPUT_WARN_GB\): \./target -> just clean-build' bo_doctor BUILD_OUTPUT_WARN_GB=0"
out=$(bo_doctor CARGO_TARGET_DIR="$bo/shared")
check "doctor says when the build folder is outside this project" "grep -qE 'the build folder is outside this project: .*/shared \(CARGO_TARGET_DIR\)' <<<\"\$out\""
check "what that costs, and the line that ends it, said once" "grep -q \"one project's clean clears\" <<<\"\$out\" && grep -q 'remove the line that sets CARGO_TARGET_DIR from your shell setup' <<<\"\$out\" && [ \$(grep -c 'outside this project' <<<\"\$out\") -eq 1 ]"
check "a CARGO_TARGET_DIR inside the project is not shared" "! says 'outside this project' bo_doctor CARGO_TARGET_DIR='$bo/proj/target' && ! says 'outside this project' bo_doctor CARGO_TARGET_DIR=build-out"
check "the heavy recipes do not say it" "! says 'outside this project' bw env CARGO_TARGET_DIR='$bo/shared' BUILD_WAIT_MINUTES=0.1 just check"
for v in 'debug = true' 'debug = 0'; do printf '[package]\nname = "bo"\n\n[profile.dev]\n%s\n' "$v" > Cargo.toml
  check "a dev debug level the project chose ends the question ($v)" "w=\$(bw just _stack-advice 2>&1) && [ -z \"\$w\" ]"; done
printf '[package]\nname = "bo"\n\n[profile.release]\ndebug = 1\n' > Cargo.toml
check "a debug level for release alone does not" "says 'line-tables-only' bw just _stack-advice"

# clean-build: the size first, a shared folder refused, its own cleared on a yes.
out=$(bw env CARGO_TARGET_DIR="$bo/shared" sh -c "printf 'y\n' | just clean-build" 2>&1); rc=$?
check "clean-build refuses a shared folder, says why, and runs no cargo clean" "[ \$rc -ne 0 ] && grep -q 'would clear their builds as well' <<<\"\$out\" && ! grep -q 'fake cargo clean' <<<\"\$out\""
out=$(bw sh -c "just clean-build </dev/null" 2>&1)
check "on this project's own folder it says the size and asks first" "grep -qE 'Build output: [0-9]+ KB, in \./target' <<<\"\$out\" && grep -qE '\[(y/N|e/H)\]' <<<\"\$out\""
check "and deletes nothing without a yes" "grep -q 'Nothing deleted' <<<\"\$out\" && ! grep -q 'fake cargo clean' <<<\"\$out\""
check "with the person's yes it clears the folder it measured, and no other" "says 'fake cargo clean --target-dir \./target' bw sh -c \"printf 'y\n' | just clean-build\""

# A build folder inside the project must be one git ignores (3.25.1).
cp .gitignore "$bo/gi.bak" 2>/dev/null || : > "$bo/gi.bak"
printf '/elsewhere\n' > .gitignore
check "doctor says when git does not ignore the build folder, and the line to add" "says 'git does not ignore the build folder, so a save would commit it: target/' bo_doctor && says 'Add this line to .gitignore: target/' bo_doctor"
printf 'target/\n' > .gitignore
check "and nothing once it is ignored"                                  "! says 'git does not ignore the build folder' bo_doctor"
cp "$bo/gi.bak" .gitignore
check "nor about a folder outside the project, which is said once, the other way" "! says 'git does not ignore the build folder' bo_doctor CARGO_TARGET_DIR='$bo/shared'"

# From the review of spec 015: the cases the first version got wrong.
out=$(bw env PS_BUSY=99 PS_STOPPED=1 BUILD_WAIT_MINUTES=0.02 just _build-wait 2>&1)
check "a build stopped with Ctrl-Z is not a build that is running" "[ -z \"\$out\" ]"
out=$(bo_doctor CARGO_META_TARGET="$bo/shared")
check "a folder a config file chose is found through cargo itself" "grep -qE 'the build folder is outside this project: .*/shared\$' <<<\"\$out\""
check "and doctor names the config line, not a variable nobody set" "grep -q 'change the \[build\] target-dir line in a .cargo/config.toml' <<<\"\$out\" && ! grep -q 'remove the line that sets' <<<\"\$out\""
out=$(bw env CARGO_META_TARGET="$bo/shared" sh -c "printf 'y\n' | just clean-build" 2>&1); rc=$?
check "and clean-build measures and refuses that folder, not ./target" "[ \$rc -ne 0 ] && grep -q '$bo/shared' <<<\"\$out\" && ! grep -q 'fake cargo clean' <<<\"\$out\""
check "a folder cargo names inside the project is not outside it" "! says 'outside this project' bo_doctor CARGO_META_TARGET='$bo/proj/target'"
s=$SECONDS; out=$(bw env PATH="$bo/slowdu:$bo/bin:$PATH" just _build-size target 1 2>&1); took=$((SECONDS - s))
check "a folder too big to measure in time says so, and in time" "[ \"\$out\" = timeout ] && [ $took -lt 5 ]"
out=$(bw env PATH="$bo/slowdu:$bo/bin:$PATH" BUILD_MEASURE_SECONDS=1 just doctor 2>&1 | sed -n '/^Repo:/,/^$/p')
check "doctor says a folder is too big to measure instead of saying nothing" "grep -q 'build output is too big to measure in 1s (BUILD_MEASURE_SECONDS): \./target -> just clean-build' <<<\"\$out\""
mkdir -p "$bo/elsewhere" && head -c 40000 /dev/urandom > "$bo/elsewhere/blob" && ln -s "$bo/elsewhere" "$bo/link"
read -r lkb _ <<<"$(bw just _build-size "$bo/link" 10)"
check "a build folder that is a link is measured where it points" "[ \"\${lkb:-0}\" -ge 30 ]"
mkdir -p "$bo/.cargo" && printf '[profile.dev]\ndebug = "line-tables-only"\n' > "$bo/.cargo/config.toml"
check "a debug level in a .cargo/config.toml above the project ends the question" "w=\$(bw just _stack-advice 2>&1) && [ -z \"\$w\" ]"
rm -rf "$bo/.cargo"
git add -A >/dev/null 2>&1
out=$(bw env PS_BUSY=1 BUILD_WAIT_MINUTES=0.05 just save "a save while another build runs" 2>&1)
check "a save waits where the person can see it, then saves" "grep -q '^Another build is running' <<<\"\$out\" && [ \"\$(git log -1 --format=%s)\" = 'chore: a save while another build runs' ]"

# Portable by construction: what this spec added reads no Mac-only tool or path.
body() { awk -v r="$1" 'index($0, r) == 1 && substr($0, length(r) + 1, 1) ~ /[ :]/ { on = 1; next } on && /^[^ \t]/ { exit } on' "$2"; }
added015() {
  local r
  for r in _build-wait _build-size _build-shared; do body "$r" "$root/.ai-backbone/core.just"; done
  for r in _build-info clean-build _stack-advice; do body "$r" "$root/.ai-backbone/examples/stack-rust.just"; done
  sed -n '/# The build folder, where the language layer/,/just _stack-advice 2>/dev\/null/p' "$root/.ai-backbone/core.just"
}
check "nothing spec 015 added names a Mac, a Mac-only tool or a Mac-only path" "[ \$(added015 | wc -l) -gt 100 ] && ! grep -qiE 'sysctl|launchctl|pgrep|stat -f|readlink -f|du -b|sed -i|/Users/|Library/|osascript|pbcopy|brew |xcode|darwin|macos' <<<\"\$(added015)\""
check "the session skill says to wait for a build already running" "grep -q '^## Before a long build' .agents/skills/session/SKILL.md && grep -q 'look for a build already running' .agents/skills/session/SKILL.md && grep -q 'just _build-wait' .agents/skills/session/SKILL.md && grep -q 'memory when they link' .agents/skills/session/SKILL.md"

# ── spec 015: the Flutter layer ──
# Lifted from the first Flutter project on this backbone (backlog 2026-09-19 and
# 2026-09-22). There is no Flutter in this suite and none is installed: flutter
# and dart are stand-ins, first on the PATH, that write down what they were
# asked and in which folder. What is checked is what the layer asks of them,
# never a build. Every run that could reach a flutter goes through `fx`, so a
# slip in the layer can only ever reach the stand-in.
echo "== the Flutter layer (spec 015) =="
fl="$tmp/fl"; mkdir -p "$fl/fakes" "$fl/shim" "$fl/linux" "$fl/ws"
cat > "$fl/fakes/flutter" <<'EOF'
#!/bin/sh
echo "flutter $* @ ${PWD##*/}" >> "$FL_LOG"
case "$1 $2" in
  "analyze "*) [ -n "${FL_ANALYZE_FAILS:-}" ] && { echo "1 issue found."; exit 1; } ;;
  "pub upgrade") printf '%b\n' "${FL_DRY:-Resolving dependencies...\nNo dependencies would change.}" ;;
  "build apk") echo "Execution failed: Error while executing process /jdk/bin/jlink"; exit 1 ;;
  "--version "*) echo "Flutter 0.0.0 (a stand-in)" ;;
esac
exit 0
EOF
cat > "$fl/fakes/dart" <<'EOF'
#!/bin/sh
echo "dart $* @ ${PWD##*/}" >> "$FL_LOG"
[ "$1" = test ] && [ -n "${FL_DART_FAILS:-}" ] && exit 1
[ "$1" = format ] && [ -n "${FL_FORMAT_FAILS:-}" ] && { echo "Changed lib/a.dart"; exit 1; }
exit 0
EOF
printf '#!/bin/sh\necho Linux\n' > "$fl/linux/uname"
chmod +x "$fl/fakes/flutter" "$fl/fakes/dart" "$fl/linux/uname"
ln -sf "$(command -v just)" "$fl/shim/just"
fx() { env PATH="$fl/fakes:$PATH" FL_LOG="$fl/log" "$@"; }
L="$root/.ai-backbone/examples/stack-flutter.just"; W="$root/.ai-backbone/examples/ci-flutter.yml"
# What the file says, without its comments: the comments name the tools it
# refuses (dart analyze) and the recipe it leaves out (test-fast) on purpose.
lcode=$(sed '/^[[:space:]]*#/d' "$L"); wf=$(sed '/^[[:space:]]*#/d' "$W")
check "stack-flutter.just parses as a justfile on its own"          "just -f '$L' -d '$fl' --summary"
lsum=$(just -f "$L" -d "$fl" --summary 2>&1)
check "it has the recipes the spec names, and no test-fast"         "( for r in get lint fmt test outdated run devices build-android build-ios clean versions check-versions; do grep -qw -- \"\$r\" <<<\"\$lsum\" || exit 1; done ) && ! grep -qw test-fast <<<\"\$lsum\""
check "it tells doctor its tools and its root files"                "grep -q '^_stack-doctor:' '$L' && grep -q '^_root-allow:' '$L'"
check "it analyzes with flutter analyze, never dart analyze"        "grep -q 'flutter analyze' <<<\"\$lcode\" && ! grep -q 'dart analyze' <<<\"\$lcode\""
check "its header lists what it does not do yet, each with its event" "( for w in 'release signing' 'store upload' 'build-number bump' 'flavors' 'device integration' 'golden tests' 'MCP server' 'toolchain line in'; do grep -q \"^#.*\$w\" '$L' || exit 1; done )"
# The names are the project's own words (its apps, the earlier games) and are
# private: they live in brain/private-names.txt on the maintainer's machine,
# one per line, and never in this file, because the repository is public
# (3.27.1). The engine's name and a home folder, which stands for anything of
# one machine, are looked for everywhere.
names=$(awk '!/^#/ && NF' "$root/brain/private-names.txt" 2>/dev/null | paste -s -d '|' - || true)
check "no project or machine of the project it came from is named" "! grep -qiE '${names:+$names|}flame|game|/Users/|/home/' '$L' '$W'"

# A folder with the layer and nothing else yet: between `just stack flutter` and
# `flutter create`, where a save used to stop in the lint hook.
cd "$fl/ws" || exit 1
printf "import? 'stack.just'\n" > Justfile; cp "$L" stack.just
check "with no pubspec.yaml yet, lint passes, says so, and asks Flutter nothing" "says 'nothing to lint' fx just lint && fx just lint && fx just test && [ ! -s '$fl/log' ]"
check "and get stops with a sentence saying what to make first"      "! fx just get >/dev/null 2>&1 && says 'flutter create --project-name <name> src' fx just get"
check "the workspace is src/, until a pubspec.yaml is at the root"   "[ \"\$(just --evaluate ws_dir)\" = src ] && [ -z \"\$(just _root-allow)\" ]"
# A pub workspace: a pure package and an app beside the root, one member line
# commented out, one member that is not there.
mkdir -p src/core/lib src/core/test src/app/lib src/app/test src/app/android/app src/app/ios/Runner
printf 'name: w\nenvironment:\n  sdk: ^3.13.4\n  flutter: 3.47.5   # the pin\nworkspace:\n  - core\n  # - gone\n  - app\n  - "not-here"\n' > src/pubspec.yaml
printf 'name: core\nresolution: workspace\ndev_dependencies:\n  test: ^1.25.6\n' > src/core/pubspec.yaml
printf 'name: app\nversion: 1.2.3+45\nresolution: workspace\ndependencies:\n  flutter:\n    sdk: flutter\n' > src/app/pubspec.yaml
touch src/app/lib/main.dart
: > "$fl/log"; fx just get >/dev/null 2>&1; fx just lint >/dev/null 2>&1; fx just test >/dev/null 2>&1; flog=$(cat "$fl/log")
check "the members are read from the workspace: list"              "[ \"\$(just _members src | tr '\\n' ' ')\" = 'core app ' ]"
check "get and analyze run once, at the workspace root"            "[ \$(grep -cx 'flutter pub get @ src' <<<\"\$flog\") -eq 1 ] && [ \$(grep -cx 'flutter analyze @ src' <<<\"\$flog\") -eq 1 ]"
check "the format check names every member's Dart folders, not ." "grep -qx 'dart format --output=none --set-exit-if-changed core/lib core/test app/lib app/test @ src' <<<\"\$flog\""
check "a package without Flutter runs dart test, the app flutter test" "grep -qx 'dart test @ core' <<<\"\$flog\" && grep -qx 'flutter test @ app' <<<\"\$flog\" && ! grep -qx 'flutter test @ core' <<<\"\$flog\""
: > "$fl/log"; out=$(fx env FL_DART_FAILS=1 just test 2>&1); rc=$?
check "a member that fails does not stop the others, and the end names it" "[ $rc -ne 0 ] && grep -qx 'Failed: src/core' <<<\"\$out\" && grep -qx 'flutter test @ app' '$fl/log'"
: > "$fl/log"
check "the workspace root is no app: run says so and names the apps"  "! fx just run >/dev/null 2>&1 && says 'is the workspace root' fx just run && says '^The apps here: app\\. ' fx just run"
check "an app folder that is not there stops with one sentence"       "says '^There is no folder src/nope/' fx just app=nope run && ! says 'recipe .?_app' fx just app=nope run"
check "and Flutter was never asked"                                    "[ ! -s '$fl/log' ]"
check "just app=<name> run runs that app, on the device named"         "fx just app=app run emulator-1 && grep -qx 'flutter run -d emulator-1 @ app' '$fl/log'"
# The JDK lesson: doctor was green, the APK died in jlink, and Flutter's own hint
# blamed the Android Gradle Plugin (2026-09-19).
check "an APK that dies in jlink is followed by the JDK sentence, and still fails" "! fx just app=app build-android >/dev/null 2>&1 && says 'flutter config --jdk-dir' fx just app=app build-android"
: > "$fl/log"
check "an iOS build on a machine that is not a Mac says so, and asks Flutter nothing" "says 'needs macOS with Xcode, and this machine runs Linux' env PATH=\"$fl/linux:$fl/fakes:\$PATH\" FL_LOG='$fl/log' just app=app build-ios && [ ! -s '$fl/log' ]"
if [ ! -x /usr/bin/flutter ] && [ ! -x /bin/flutter ]; then
  check "with no Flutter on the machine, lint says so in one sentence" "says '^Flutter is not on this machine' env PATH='$fl/shim:/usr/bin:/bin' just lint && ! says 'command not found|recipe .?_need-flutter' env PATH='$fl/shim:/usr/bin:/bin' just lint"
fi
# outdated alone printed an all-clear that was not true (measured 2026-09-19).
: > "$fl/log"
check "outdated lists the project's own packages and asks pub what an upgrade would move" "fx just outdated >/dev/null 2>&1 && grep -qx 'flutter pub outdated --no-transitive @ src' '$fl/log' && grep -qx 'flutter pub upgrade --dry-run @ src' '$fl/log'"
check "the all-clear only when pub says nothing would move"            "says 'would move nothing' fx just outdated && says '^  > meta 1\\.16\\.0' fx env FL_DRY='> meta 1.16.0 (was 1.15.0)\\nWould change 1 dependency.' just outdated && ! says 'would move nothing' fx env FL_DRY='> meta 1.16.0 (was 1.15.0)' just outdated && ! says 'would move nothing' fx env FL_DRY='Something pub never said before' just outdated"
printf '<plist>\n<dict>\n\t<key>CFBundleShortVersionString</key>\n\t<string>$(FLUTTER_BUILD_NAME)</string>\n\t<key>CFBundleVersion</key>\n\t<string>$(FLUTTER_BUILD_NUMBER)</string>\n</dict>\n</plist>\n' > src/app/ios/Runner/Info.plist
printf 'android {\n    defaultConfig {\n        versionCode = flutter.versionCode // was 7\n        versionName = flutter.versionName\n    }\n}\n' > src/app/android/app/build.gradle.kts
check "versions reads every app's version from its pubspec.yaml"      "says '^src/app +1\\.2\\.3 +45\$' fx just versions"
check "check-versions passes apps that take it from there"             "says '^ok  every app takes its version' fx just check-versions"
perl -pi -e 's/versionCode = flutter\.versionCode/versionCode = 7/' src/app/android/app/build.gradle.kts
check "and fails on a number typed into build.gradle by hand, naming it" "! fx just check-versions >/dev/null 2>&1 && says 'HAND-SET  versionCode in src/app/android/app/build.gradle.kts' fx just check-versions"
# From the review of spec 015. Lint's one job is to fail: the stand-ins can now
# be made to complain, and lint must not pass when they do.
check "lint fails when the analyzer finds something"                  "! fx env FL_ANALYZE_FAILS=1 just lint >/dev/null 2>&1"
check "and when the formatter would change a file"                    "! fx env FL_FORMAT_FAILS=1 just lint >/dev/null 2>&1"
# A member named in pure: dart test whatever its pubspec says, and a stop the
# day it takes Flutter in, on lint and on test alike.
: > "$fl/log"
check "a member named in pure runs dart test"                          "fx just pure=core test >/dev/null 2>&1 && grep -qx 'dart test @ core' '$fl/log'"
cp src/core/pubspec.yaml "$fl/core.pubspec"; printf 'dependencies:\n  flutter:\n    sdk: flutter\n' >> src/core/pubspec.yaml
check "a pure member that takes Flutter in stops lint and test, by name" "! fx just pure=core lint >/dev/null 2>&1 && says 'named in pure, and now depend on Flutter: core' fx just pure=core test && ! fx just pure=core test >/dev/null 2>&1"
cp "$fl/core.pubspec" src/core/pubspec.yaml
# The two other ways pub writes a list, and one this cannot read.
cp src/pubspec.yaml "$fl/ws.pubspec"
printf 'name: w\nworkspace:\n- core\n- app\nenvironment:\n  sdk: ^3.13.4\n' > src/pubspec.yaml
check "a workspace: list written at column 0 is read"                   "[ \"\$(just _members src | tr '\\n' ' ')\" = 'core app ' ]"
printf 'name: w\nworkspace: [\n  core,\n  app\n]\n' > src/pubspec.yaml
check "and a list in brackets over several lines"                        "[ \"\$(just _members src | tr '\\n' ' ')\" = 'core app ' ]"
printf 'name: w\nworkspace:\nenvironment:\n  sdk: ^3.13.4\n' > src/pubspec.yaml
check "a workspace: key with no member it can read stops test and lint"  "! fx just test >/dev/null 2>&1 && says 'no member could be read' fx just lint && ! fx just lint >/dev/null 2>&1"
cp "$fl/ws.pubspec" src/pubspec.yaml
# One app in src/<name>, the shape getting-started shows beside src/server.
mkdir -p "$fl/one/src/mobile/lib" "$fl/one/src/mobile/test" && cd "$fl/one" || exit 1
printf "import? 'stack.just'\n" > Justfile; cp "$L" stack.just
printf 'name: mobile\ndependencies:\n  flutter:\n    sdk: flutter\n' > src/mobile/pubspec.yaml; touch src/mobile/lib/main.dart
: > "$fl/log"
check "one app in src/<name>, app unset: lint stops and names the line to set" "! fx just lint >/dev/null 2>&1 && says 'in src/mobile/ but these recipes look in src/' fx just lint && says 'set app := \"mobile\"' fx just lint && [ ! -s '$fl/log' ]"
check "with app set, lint reads that app"                                "fx just app=mobile lint >/dev/null 2>&1 && grep -qx 'flutter analyze @ mobile' '$fl/log'"
# Build folders git does not ignore stop lint, before a save commits them.
git init -q . && mkdir -p src/mobile/.dart_tool src/mobile/build
check "a build folder git would save stops lint, and says which"          "! fx just app=mobile lint >/dev/null 2>&1 && says 'next save would commit them: src/mobile/.dart_tool/ src/mobile/build/' fx just app=mobile lint"
printf 'src/*/.dart_tool/\nsrc/*/build/\n' > .gitignore
check "and once they are ignored, lint goes on"                          "fx just app=mobile lint >/dev/null 2>&1"
cd "$fl/ws" || exit 1

# With pubspec.yaml at the root the root is the workspace, and doctor must not
# call what Flutter keeps there strays.
mkdir -p "$fl/root/lib" && cd "$fl/root" || exit 1
printf "import? 'stack.just'\n" > Justfile; cp "$L" stack.just; printf 'name: one\ndependencies:\n  flutter:\n    sdk: flutter\n' > pubspec.yaml; touch lib/main.dart
check "a pubspec.yaml at the root makes the root the workspace and the app" "[ \"\$(just --evaluate ws_dir)\" = . ] && [ \"\$(just _members .)\" = . ] && fx just run && says '(^| )pubspec\\.yaml pubspec\\.lock ' just _root-allow"

# ci-init flutter, in a project made the way a person makes one.
if ( cd "$root" && just new-project "$tmp/fl-app" ) >/dev/null 2>&1; then ok "a new project for the Flutter checks"; else bad "a new project for the Flutter checks"; fi
cd "$tmp/fl-app" || exit 1
check "stack flutter adds the layer and names its checks"             "says 'just ci-init flutter' fx just stack flutter && [ -f stack.just ]"
check "a save between just stack and flutter create is not stopped by lint, and asks Flutter nothing" ": > '$fl/log'; fx just save 'chore: the Flutter layer' && [ ! -s '$fl/log' ]"
out=$(fx just ci-init flutter 2>&1); rc=$?
check "ci-init flutter writes the workflow and the update bot, and exits 0" "[ $rc -eq 0 ] && grep -q 'from ci-flutter.yml' <<<\"\$out\" && [ -f .github/workflows/checks.yml ] && grep -q 'package-ecosystem: \"pub\"' .github/dependabot.yml"
check "the workflow it wrote passes the backbone's own ci-check"      "says 'still in force' just ci-check"
check "and the commit hooks accept it"                                 "fx just save 'ci: the checks GitHub runs on every push'"
check "it runs on Ubuntu only, one job, under a ten-minute cap"         "grep -qE '^ +runs-on: ubuntu-latest\$' <<<\"\$wf\" && ! grep -qi macos <<<\"\$wf\" && grep -qE '^ +timeout-minutes: 10\$' <<<\"\$wf\""
uses=$(grep -E 'uses:' <<<"$wf"); unpinned=$(grep -vE 'uses: [^@ ]+@[0-9a-f]{40} # v[0-9]' <<<"$uses")
check "every action in it is pinned to a commit, with its tag beside it" "[ -n \"\$uses\" ] && [ -z \"\$unpinned\" ] && grep -q 'subosito/flutter-action@' <<<\"\$uses\" && grep -q 'extractions/setup-just@' <<<\"\$uses\""
check "it reads the Flutter pin from the workspace root, and skips docs-only pushes" "grep -q 'flutter-version-file: src/pubspec.yaml' <<<\"\$wf\" && grep -qF \"'**/*.md'\" <<<\"\$wf\" && grep -qF \"'docs/**'\" <<<\"\$wf\""
rm -rf .github/workflows; printf 'name: one\n' > pubspec.yaml
check "with pubspec.yaml at the root, the copy is pointed there"      "fx just ci-init flutter >/dev/null 2>&1 && grep -qx '          flutter-version-file: pubspec.yaml' .github/workflows/checks.yml"
check "and doctor names what the layer needs, found or not"           "says '^  ok    flutter +Flutter 0\\.0\\.0' fx just doctor"
rm -rf .github pubspec.yaml; mkdir -p src && printf 'name: w\nenvironment:\n  flutter: 3.47.5\n' > src/pubspec.yaml
fx just ci-init flutter >/dev/null 2>&1
# The directory line that follows an ecosystem's name, and whether it names $2.
botdir() { awk -v e="\"$1\"" -v d="\"$2\"" 'index($0, e) { p = 1 } p && /directory:/ { exit index($0, d) ? 0 : 1 } END { if (!p) exit 1 }' .github/dependabot.yml; }
check "the update bot's pub entry names the folder of the pubspec.yaml"   "botdir pub /src"
check "and its entry for the workflow's actions stays at the root"       "botdir github-actions /"
rm -rf .github src/pubspec.yaml; mkdir -p src/mobile && printf 'name: mobile\n' > src/mobile/pubspec.yaml
fx just ci-init flutter >/dev/null 2>&1
check "one app in src/<name>: both files point at it"                    "grep -qx '          flutter-version-file: src/mobile/pubspec.yaml' .github/workflows/checks.yml && grep -q '\"/src/mobile\"' .github/dependabot.yml"
rm -rf .github; mkdir -p src/server && printf '[package]\nname = \"server\"\n' > src/server/Cargo.toml
out=$(fx just ci-init 2>&1); rc=$?
check "Flutter and Rust in one project: ci-init asks which, and writes nothing" "[ $rc -ne 0 ] && grep -q 'more than one language: rust flutter' <<<\"\$out\" && grep -q 'just ci-init flutter' <<<\"\$out\" && [ ! -d .github ]"
rm -rf src/server
check "outdated does not offer the update bot a project already has"     "mkdir -p .github && touch .github/dependabot.yml && ! says 'just ci-init flutter' fx just app=mobile outdated"
cd "$tmp" || exit 1

# ── spec 015: the other ideas ──
# A folder as a reference, `just stale`, `just adr --amends` and the pre-push
# hook: the backlog lines of 2026-09-22 (Smash, three) and 2026-09-23 (Smash,
# one). A throwaway project of its own; the commits planted below skip the
# hooks, which are not what is tested, and prek is a stand-in where hooks are.
echo "== spec 015: the other ideas =="
o="$tmp/s15"
( cd "$root" && just new-project "$o" ) >/dev/null 2>&1
cd "$o" || exit 1
# A reference that has no address: an old repo of the person's own (Smash kept
# three earlier games like that, moved into .references/ by hand). A git repo is
# cloned in the way a URL is, and listed with url = ""; the home folder is
# written as ~, so the list carries no user name.
lr="$tmp/s15-old-game"; mkdir -p "$lr"
( cd "$lr" && git init -qb main && echo old > game.txt && git add -A && git commit -qm "chore: an old game" --no-verify ) >/dev/null 2>&1
lr_before=$(cd "$lr" && git rev-parse HEAD && ls -a)
check "ref-add takes a folder: a git repo is cloned in and listed with no address" "env HOME='$tmp' just ref-add '$lr' 'an old game of mine' && [ -f .references/s15-old-game/game.txt ] && [ ! -L .references/s15-old-game ] && [ \"\$(grep -A1 'name   = \"s15-old-game\"' .references/references.toml | tail -1)\" = 'url    = \"\"' ]"
check "and where it came from, as from and with ~ for the home folder" "grep -qx 'from   = \"~/s15-old-game\"' .references/references.toml && ! grep -q '^path   = \"~/s15-old-game' .references/references.toml"
check "and the folder it came from is not written"          "[ \"\$(cd '$lr' && git rev-parse HEAD && ls -a)\" = \"\$lr_before\" ]"
lr2="$tmp/s15-mirror"; mkdir -p "$lr2"
( cd "$lr2" && git init -qb main && echo x > x.txt && git add -A && git commit -qm "chore: a clone" --no-verify && git remote add origin https://example.com/someone/mirror.git ) >/dev/null 2>&1
check "a folder that has an address elsewhere is listed with that address, fetching nothing" "just ref-add '$lr2' 'a clone of something public' && [ -f .references/s15-mirror/x.txt ] && grep -qx 'url    = \"https://example.com/someone/mirror.git\"' .references/references.toml"
mkdir -p .references/by-hand && echo notes > .references/by-hand/notes.txt
check "a folder already in .references/ is listed where it stands" "just ref-add .references/by-hand 'moved here by hand' && grep -qF 'name   = \"by-hand\"' .references/references.toml && [ -f .references/by-hand/notes.txt ]"
mkdir -p "$tmp/s15-loose" && echo x > "$tmp/s15-loose/f.txt"
out=$(just ref-add "$tmp/s15-loose" 'loose' 2>&1); rc=$?
check "a loose folder elsewhere is refused, with the way to do it, and nothing is copied" "[ $rc -ne 0 ] && grep -q 'is not a git repository' <<<\"\$out\" && grep -q 'Move it into .references/' <<<\"\$out\" && [ ! -e .references/s15-loose ]"
check "the references guide says a local-only entry is allowed" "grep -q 'A folder with no address' .references/README.md && grep -q 'url = \"\"' .references/README.md"
check "ref-fetch counts a local folder that is here as there" "says '^  ok      \.references/by-hand \(local only' just ref-fetch"
rm -rf .references/by-hand
out=$(just ref-fetch 2>&1); rc=$?
check "and skips one that is not, in one line, fetching nothing" "[ $rc -eq 0 ] && [ \"\$(grep -c 'by-hand' <<<\"\$out\")\" = 1 ] && grep -q '^  skipped \.references/by-hand: local only' <<<\"\$out\" && grep -q '^0 fetched' <<<\"\$out\" && [ ! -e .references/by-hand ]"
check "and says where one came from, when the list knows" "rm -rf .references/s15-old-game && says 'skipped \.references/s15-old-game: .*came from ~/s15-old-game' just ref-fetch"
# From the review of spec 015. `path` keeps the meaning lists already give it,
# where a reference lives, read in place — a project's real list has an entry
# like that — and a clone's origin is recorded as `from`.
mkdir -p "$tmp/s15-elsewhere" && echo keep > "$tmp/s15-elsewhere/k.txt"
printf '\n[[ref]]\nname   = "elsewhere"\npath   = "%s"\nnote   = "read where it stands"\n' "$tmp/s15-elsewhere" >> .references/references.toml
printf '\n[[ref]]\nname   = "gone-copy"\npath   = ".references/gone-copy"\nrestore = "git clone .archive/x.bundle .references/gone-copy"\n' >> .references/references.toml
out=$(just ref-fetch 2>&1)
check "a folder listed by hand with path is read where it stands"  "grep -qF '  ok      $tmp/s15-elsewhere (local only, read where it stands)' <<<\"\$out\""
check "and one that is not there says so, with the way to bring it back" "grep -qF '  skipped .references/gone-copy: local only' <<<\"\$out\" && grep -qF 'to bring it back: git clone .archive/x.bundle .references/gone-copy' <<<\"\$out\""
# An address with a user and a token in it is listed without them.
lr3="$tmp/s15-secret"; mkdir -p "$lr3"
( cd "$lr3" && git init -qb main && echo x > x.txt && git add -A && git commit -qm "chore: x" --no-verify && git remote add origin https://someone:ghp_NOTREAL@example.com/org/private.git ) >/dev/null 2>&1
out=$(just ref-add "$lr3" 'a private one' 2>&1)
check "an address with a user and a token is listed without them" "grep -qx 'url    = \"https://example.com/org/private.git\"' .references/references.toml && ! grep -q 'ghp_NOTREAL' .references/references.toml && ! grep -q 'ghp_NOTREAL' <<<\"\$out\""
# A repository cloned into .references/ by hand keeps its address.
( git clone -q "$lr2" .references/handclone && git -C .references/handclone remote set-url origin https://example.com/org/handclone.git ) >/dev/null 2>&1
check "a repository cloned into .references/ by hand is listed with its address" "just ref-add .references/handclone 'cloned by hand' >/dev/null 2>&1 && grep -qx 'url    = \"https://example.com/org/handclone.git\"' .references/references.toml"

# just adr --amends: the new decision, and one pointer line in the old one.
just adr first-choice >/dev/null 2>&1
check "adr --amends writes the new decision and names the old one on its Relates line" "just adr second-choice --amends 1 'the first one, narrowed' && [ -f docs/adr/0002-second-choice.md ] && grep -qxF '**Relates to:** amends [0001](0001-first-choice.md).' docs/adr/0002-second-choice.md"
check "and puts the pointer on the old one's Status line" "grep -qxF \"**Status:** accepted; amended by [0002](0002-second-choice.md) on \$(date +%Y-%m-%d): the first one, narrowed\" docs/adr/0001-first-choice.md"
check "a second amendment adds 'and by' to the same line"  "just adr --amends 0001 third-choice && grep -q '^\*\*Status:\*\* accepted; amended by \[0002\].*; and by \[0003\](0003-third-choice.md) on .*: third choice\$' docs/adr/0001-first-choice.md && [ \$(grep -c '^\*\*Status:' docs/adr/0001-first-choice.md) = 1 ]"
check "a decision that is not there writes nothing"   "! just adr fourth --amends 9 && [ ! -e docs/adr/0004-fourth.md ] && [ \$(ls docs/adr | wc -l) -eq 3 ]"
check "and the words typed stay words"                 "just adr fifth --amends 2 '\$(touch $tmp/PWNED15) & \\1' && [ ! -e '$tmp/PWNED15' ] && grep -qF ': \$(touch $tmp/PWNED15) & \\1' docs/adr/0002-second-choice.md"
printf -- '---\nstatus: accepted\n---\n# 9 — front matter\n\n## Context\n' > docs/adr/0009-front-matter.md
printf -- '# 10 — late status\n\n## Context\n\n**Status:** accepted\n' > docs/adr/0010-late-status.md
just adr sixth --amends 9 'with: a colon' >/dev/null 2>&1; just adr seventh --amends 10 'late' >/dev/null 2>&1
check "adr --amends leaves a YAML front matter as it was"  "[ \"\$(sed -n 2p docs/adr/0009-front-matter.md)\" = 'status: accepted' ] && grep -q '^\*\*Status:\*\* accepted; amended by .*: with: a colon' docs/adr/0009-front-matter.md"
check "and finds a Status line below the first section rather than adding a second" "[ \$(grep -c '^\*\*Status:' docs/adr/0010-late-status.md) = 1 ] && grep -q '^\*\*Status:\*\* accepted; amended by' docs/adr/0010-late-status.md"
rm -f docs/adr/0009-front-matter.md docs/adr/0010-late-status.md docs/adr/0011-sixth.md docs/adr/0012-seventh.md
# just stale. A folder renamed, a page deleted, an old name in docs/renames.toml,
# an amended ADR that keeps old names on purpose, a path git ignores, and the
# words that are not paths at all: an address, a glob, a command, a placeholder.
mkdir -p server/src out && echo 'fn main() {}' > server/src/main.rs && echo old > docs/old-page.md && echo gen > out/report.txt
git add -A && git commit -qm "feat: a server" --no-verify
git mv server backend && git rm -rq docs/old-page.md out && echo 'out/' >> .gitignore && git commit -qam "refactor: the server is the backend" --no-verify
printf '[[rename]]\nold  = "games/"\nnew  = "src/games/"\ndate = "2026-09-22"\n' > docs/renames.toml
cat > docs/notes.md <<'MD'
# Notes

The entry point is `server/src/main.rs:1`, and `docs/old-page.md` said why.
Fine: `backend/src/main.rs`, `owner/repo`, `Node.js`, `docs/never-was.md`, `https://example.com/server/x`.
Not paths: `cargo run -p server`, `docs/specs/NNN-<name>.md`, `server/*.rs`, `out/report.txt`, `.archive/`.
```bash
cat server/src/main.rs games/
```
The games live in games/ still.
Renamed once: `games/` became `src/games/`, and src/games/x is fine.
MD
printf 'It began in `server/src/main.rs`.\n' >> docs/adr/0001-first-choice.md
out=$(just stale 2>&1); rc=$?
check "stale finds a path whose folder was renamed, as file:line" "grep -qF 'docs/notes.md:3: \`server/src/main.rs:1\` is no longer here' <<<\"\$out\""
check "and a page that was deleted"                    "grep -qF 'docs/notes.md:3: \`docs/old-page.md\` is no longer here' <<<\"\$out\""
check "and an old name from docs/renames.toml, fenced or not" "grep -qF 'docs/notes.md:9: \`games/\` is \`src/games/\` now (renamed 2026-09-22)' <<<\"\$out\" && grep -qF 'docs/notes.md:7: \`games/\`' <<<\"\$out\""
check "and nothing that was never a path of this repository" "! grep -qE 'owner/repo|Node\\.js|never-was|example\\.com|NNN|cargo|server/\\*|backend' <<<\"\$out\""
check "nor what git ignores, nor a fenced path, nor a line that names the new name too" "! grep -qE 'out/report|notes\\.md:(5|10):|notes\\.md:7: .server' <<<\"\$out\""
check "and it skips an ADR whose Status line says amended" "! grep -q 'docs/adr/0001' <<<\"\$out\""
check "and says how many, and exits 0: a report, not a failure" "[ $rc -eq 0 ] && grep -q '^4 line(s) in 1 file(s) name something that has moved or gone' <<<\"\$out\""
check "stale stays quiet on the backbone's own docs"   "says '^Nothing stale' just -f '$root/Justfile' -d '$root' stale"
mkdir -p "$tmp/s15-noperl" && printf '#!/bin/sh\nexit 2\n' > "$tmp/s15-noperl/perl" && chmod +x "$tmp/s15-noperl/perl"
out=$(PATH="$tmp/s15-noperl:$PATH" just stale 2>&1)
check "a perl that fails is no all-clear: stale says nothing was checked" "grep -q 'nothing was checked' <<<\"\$out\" && ! grep -q 'Nothing stale' <<<\"\$out\""
# lint runs it and does not fail on it. The Rust layer's lint with a stand-in
# cargo that passes: nothing is built.
mkdir -p "$tmp/s15-bin" && printf '#!/bin/sh\nexit 0\n' > "$tmp/s15-bin/cargo" && chmod +x "$tmp/s15-bin/cargo"
just stack rust >/dev/null 2>&1; : > Cargo.toml
check "the Rust layer's lint reports stale lines and still passes" "out=\$(PATH='$tmp/s15-bin:'\"\$PATH\" just lint 2>&1) && grep -q 'server/src/main.rs:1' <<<\"\$out\""
check "and the Swift layer's lint ends with it too, never failing on it" "grep -q '^    just stale || true\$' '$root/.ai-backbone/examples/stack-swift.just' && grep -q '^    -@just stale\$' '$root/.ai-backbone/examples/stack-rust.just'"
rm -f Cargo.toml stack.just
# The pre-push hook: in the seed config, commented; installed once it is not.
fp="$tmp/s15-prek"; mkdir -p "$fp"
printf '#!/bin/sh\necho "$*" >> "%s/calls"\nexit 0\n' "$fp" > "$fp/prek"; chmod +x "$fp/prek"
prek_hooks() { rm -f "$fp/calls"; PATH="$fp:$PATH" just hooks-install; }
check "the seed config carries a pre-push just test hook, commented out" "grep -qx '  #       entry: just _test-if-any' '$root/.ai-backbone/seed/pre-commit-config.yaml' && grep -qx '  #       stages: \[pre-push\]' .pre-commit-config.yaml && [ -z \"\$(just _push-stage)\" ]"
check "hooks-install without a pre-push stage installs pre-commit and commit-msg only" "prek_hooks && grep -qx 'install -t pre-commit -t commit-msg' '$fp/calls' && ! grep -q 'pre-push' '$fp/calls'"
perl -pi -e 's/^  # (?=- repo: local$|  hooks:$|    - id: tests$|      [a-z_]+: )/  /' .pre-commit-config.yaml
check "uncommented, the config has a pre-push stage"   "[ \"\$(just _push-stage)\" = yes ] && { ! command -v prek >/dev/null || prek validate-config .pre-commit-config.yaml >/dev/null 2>&1; }"
out=$(prek_hooks 2>&1)
check "and hooks-install installs it, and says so"      "grep -qx 'install -t pre-commit -t commit-msg -t pre-push' '$fp/calls' && grep -q 'pre-push ones before every push' <<<\"\$out\""
rm -f "$fp/calls"; PATH="$fp:$PATH" just template-update >/dev/null 2>&1
check "template-update installs the push stage too, when the config has one" "grep -qx 'install -t pre-commit -t commit-msg -t pre-push' '$fp/calls'"
rm -f .git/hooks/pre-push
check "doctor says when git will not run a pre-push hook the config has" "says 'has a pre-push hook and git will not run it -> just hooks-install' repo_doctor"
touch .git/hooks/pre-push
check "and nothing once it is there"                   "! says 'pre-push hook and git will not' repo_doctor"
cd "$p" || exit 1

# ── spec 016: project versions ──
# A project's own version: cut by `just release` at a meaningful point, read
# from the kinds of the commits since the last one, written into CHANGELOG.md,
# tagged, and carried to GitHub with the backup. A throwaway project; the
# commits planted below skip the hooks, the release commit does not.
echo "== project versions (spec 016) =="
pv="$tmp/pv"
( cd "$root" && just new-project "$pv" ) >/dev/null 2>&1
cd "$pv" || exit 1
git add -A >/dev/null 2>&1; git commit -qm "chore: the project" --no-verify >/dev/null 2>&1 || true
pc() { echo "$2" >> "f-$1.txt"; git add -A; git commit -qm "$2" --no-verify; }
has_tag() { git rev-parse -q --verify "refs/tags/$1" >/dev/null; }
entry() { awk -v v="$1" 'index($0, "## [" v "]") == 1 { on = 1; next } on && /^## / { exit } on' CHANGELOG.md | sed '/./,$!d'; }
pc a "feat: a first thing — with a long tail nobody reads in a changelog"
check "no version yet: doctor says the first will be 0.1.0" "says 'no version of its own yet: the first just release makes it 0.1.0' repo_doctor"
out=$(just release 2>&1)
check "the first release is 0.1.0, whatever the commits say" "has_tag v0.1.0 && grep -q '^Released v0.1.0' <<<\"\$out\""
check "an annotated tag, on a release commit" "[ \"\$(git cat-file -t v0.1.0)\" = tag ] && [ \"\$(git log -1 --format=%s)\" = 'chore(release): v0.1.0' ] && [ \"\$(git rev-parse v0.1.0^{commit})\" = \"\$(git rev-parse HEAD)\" ]"
check "CHANGELOG.md is made, the entry drafted from the commits, each cut at its dash" "grep -qx '## \\[0.1.0\\] - $(date +%Y-%m-%d)' CHANGELOG.md && [ \"\$(entry 0.1.0)\" = \"\$(printf '### Added\\n- a first thing')\" ] && grep -qx '## \\[Unreleased\\]' CHANGELOG.md && grep -q 'keepachangelog.com' CHANGELOG.md"
check "doctor says the version" "says 'version v0.1.0, at this save' repo_doctor"
out=$(just release 2>&1)
check "nothing since the last version: it says so and changes nothing" "grep -q 'Nothing to release: no save since v0.1.0' <<<\"\$out\" && [ \$(git tag | wc -l | tr -d ' ') = 1 ]"
pc b "fix: a small thing"
check "doctor counts the saves since"                   "says 'version v0.1.0, 1 save\\(s\\) since' repo_doctor"
just release >/dev/null 2>&1
check "fixes alone make the next patch"                 "has_tag v0.1.1"
pc c "feat: another thing"; pc d "fix: and a fix"; pc d2 "chore: nothing a user notices"
just release >/dev/null 2>&1
check "a feat makes the next minor, and the entry groups what was added and fixed" "has_tag v0.2.0 && [ \"\$(entry 0.2.0)\" = \"\$(printf '### Added\\n- another thing\\n\\n### Fixed\\n- and a fix')\" ]"
pc e "feat!: a breaking change"
just release >/dev/null 2>&1
check "below 1.0.0 a breaking change is a minor step, never 1.0.0" "has_tag v0.3.0 && ! has_tag v1.0.0"
pc f "fix: needed"; printf 'x\n' >> README.md
out=$(just release 2>&1); rc=$?
check "unsaved work: refused, and nothing changes"      "[ $rc -ne 0 ] && grep -q 'there is work not saved yet' <<<\"\$out\" && ! has_tag v0.3.1"
git checkout -q -- README.md
just release major >/dev/null 2>&1
check "1.0.0 only on the word: just release major"     "has_tag v1.0.0 && ! has_tag v0.3.1"
git commit -q --allow-empty -m "fix: breaking in the body" -m "BREAKING CHANGE: the old way is gone" --no-verify
just release >/dev/null 2>&1
check "from 1.0.0 on, a breaking change is the next major" "has_tag v2.0.0"
# What a person wrote under Unreleased is the entry, and an empty one is left.
pc g "fix: one more"
perl -0pi -e 's/## \[Unreleased\]\n/## [Unreleased]\n\n### Fixed\n- Written by a person, for the people who use it.\n/' CHANGELOG.md
git add -A; git commit -qm "docs: the unreleased notes" --no-verify
just release >/dev/null 2>&1
check "an Unreleased section's text becomes the version's entry, and an empty one is left" "[ \"\$(entry 2.0.1)\" = \"\$(printf '### Fixed\\n- Written by a person, for the people who use it.')\" ] && [ -z \"\$(awk '/^## \\[Unreleased\\]/{on=1;next} on&&/^## /{exit} on' CHANGELOG.md | tr -d ' \\n')\" ]"
# The checks refuse the release commit: nothing is half-released.
pc h "fix: refused"
cp .git/hooks/pre-commit "$tmp/pv-hook" 2>/dev/null || : > "$tmp/pv-hook"
printf '#!/bin/sh\necho "a check said no"\nexit 1\n' > .git/hooks/pre-commit; chmod +x .git/hooks/pre-commit
before=$(cksum < CHANGELOG.md)
out=$(just release 2>&1); rc=$?
check "a release the checks refuse leaves no tag and no half-written changelog" "[ $rc -ne 0 ] && grep -q 'the checks refused the release commit' <<<\"\$out\" && ! has_tag v2.0.2 && [ \"\$(cksum < CHANGELOG.md)\" = \"\$before\" ] && [ -z \"\$(git status --porcelain)\" ]"
if [ -s "$tmp/pv-hook" ]; then cp "$tmp/pv-hook" .git/hooks/pre-commit; else rm -f .git/hooks/pre-commit; fi
just release >/dev/null 2>&1
# The tags reach GitHub with the backup, and only when the backup does.
git init -q --bare "$tmp/pv-hub.git" && git remote add origin "$tmp/pv-hub.git" && git push -q origin HEAD >/dev/null 2>&1
git config ai-backbone.publish-on-save true
pc i "feat: goes to GitHub"
out=$(just release 2>&1)
check "with publish-on-save on, the release and its tag reach GitHub" "grep -q -- '-> GitHub, with v2.1.0' <<<\"\$out\" && git --git-dir='$tmp/pv-hub.git' rev-parse -q --verify refs/tags/v2.1.0 >/dev/null"
git tag -a marker-1 -m marker
echo carried >> f-carry.txt
just save "fix: a save carries a tag along" >/dev/null 2>&1
check "and a save that reaches GitHub carries a tag along" "git --git-dir='$tmp/pv-hub.git' rev-parse -q --verify refs/tags/marker-1 >/dev/null"
git config ai-backbone.publish-on-save false
pc j "fix: stays here"
just release >/dev/null 2>&1
check "with it off, the release stays on this machine" "has_tag v2.1.1 && ! git --git-dir='$tmp/pv-hub.git' rev-parse -q --verify refs/tags/v2.1.1 >/dev/null"
# The Rust layer writes the version where cargo reads it. A stand-in cargo:
# the release commit's lint would otherwise build.
mkdir -p "$tmp/pv-bin" && printf '#!/bin/sh\nexit 0\n' > "$tmp/pv-bin/cargo" && chmod +x "$tmp/pv-bin/cargo"
cp "$root/.ai-backbone/examples/stack-rust.just" stack.just
printf '[workspace]\nmembers = []\n\n[workspace.package]\nversion = "0.1.0"\nedition = "2024"\n\n[package]\nname = "pv"\nversion.workspace = true\n' > Cargo.toml
git add -A; git commit -qm "feat: a Rust workspace" --no-verify
PATH="$tmp/pv-bin:$PATH" just release >/dev/null 2>&1
check "the Rust layer writes the version into [workspace.package]" "has_tag v2.2.0 && grep -qx 'version = \"2.2.0\"' Cargo.toml && grep -qx 'version.workspace = true' Cargo.toml && git show v2.2.0:Cargo.toml > '$tmp/pv-c' && grep -qx 'version = \"2.2.0\"' '$tmp/pv-c'"
printf '[package]\nname = "pv"\nversion = "0.1.0"\nedition = "2024"\n' > Cargo.toml
git add -A; git commit -qm "fix: one crate" --no-verify
PATH="$tmp/pv-bin:$PATH" just release >/dev/null 2>&1
check "and into [package] when there is no workspace version"  "has_tag v2.2.1 && grep -qx 'version = \"2.2.1\"' Cargo.toml"
check "the backbone's own versions are not this recipe's"      "says 'cut by hand' just -f '$root/Justfile' -d '$root' release"
cd "$tmp" || exit 1

echo
echo "$pass ok, $fail failed"
[ "$fail" -eq 0 ]
