#!/usr/bin/env bash
# The backbone's own test. It builds throwaway projects in a temp folder,
# adopts an existing repo, and checks what a person would see.
# Run it with:  just self-test
# Every check prints ok or FAIL; the script exits 1 if anything failed.
set -uo pipefail
# macOS ls paints directories when CLICOLOR_FORCE is set. The escape sorts
# before "AGENTS.md", and a skill name read from ls comes out painted, so a
# note about that skill is refused. Measured with CLICOLOR_FORCE=1.
unset CLICOLOR CLICOLOR_FORCE
# git hands a hook its own GIT_DIR and GIT_INDEX_FILE, and this suite runs as a
# hook on every commit that touches the core. From a linked worktree those point
# into the real repository, so every `git init`, `git add` and `git remote` the
# throwaway projects below run landed there instead of in the temp folder: it
# turned this repository bare and took its GitHub address, once (3.20.0).
# Whatever git exported, the suite starts without it.
unset $(git rev-parse --local-env-vars 2>/dev/null) 2>/dev/null || true
# Claude Code names this file for its SessionStart hook; every session-start
# below would write into the real one (spec 028).
unset CLAUDE_ENV_FILE
# Nor this machine's delegation choice. A runner with WORKER set would write
# allow rules into every throwaway project. The checks that want them set
# WORKER themselves (n-cdb28d). DELEGATE_BASE is passed through by the delegate
# checks, and a job that exported it would point every throwaway project at a
# branch that project does not have.
unset WORKER DELEGATE_BASE DELEGATE_IDLE DELEGATE_TIMEOUT DELEGATE_YES KIMI_CODE_HOME DELEGATE_MODEL DELEGATE_MCP FAKE_OPENCODE_STATUS
root="$(cd "$(dirname "$0")/.." && pwd -P)"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
# prek writes a lock and a log under its home, and refuses to run when it cannot.
# A sandbox that forbids ~/.cache/prek then fails every hook install and every
# save before a check runs. This run's own copy keeps the hooks already fetched.
# A home that is writable is left where it is, so an ordinary run copies nothing.
# Opening either cache to test it prints "Operation not permitted" here, which
# is the noise a failed redirect makes before any redirect can hide it. uv's
# lock lives in UV_CACHE_DIR, or in ~/.cache/uv when that is unset. A variable
# that already names a directory that cannot be locked is the same failure:
# `uv python find` exits and upstream used to fall back to system python3.
uv_cache="${UV_CACHE_DIR:-$HOME/.cache/uv}"
if [ -d "$uv_cache" ] && ! python3 -c 'import os,sys; raise SystemExit(0 if os.access(sys.argv[1], os.W_OK) else 1)' "$uv_cache"; then
  export UV_CACHE_DIR="$tmp/uv-cache"
  mkdir -p "$UV_CACHE_DIR"
fi
if [ -z "${PREK_HOME:-}" ] && [ -d "$HOME/.cache/prek" ] && ! python3 -c 'import os,sys; raise SystemExit(0 if os.access(sys.argv[1], os.W_OK) else 1)' "$HOME/.cache/prek"; then
  export PREK_HOME="$tmp/prek-home"
  mkdir -p "$PREK_HOME"
  for e in "$HOME/.cache/prek"/* "$HOME/.cache/prek"/.[!.]*; do
    [ -e "$e" ] || continue
    b=$(basename "$e")
    case "$b" in prek.log|.lock) continue ;; esac
    cp -a "$e" "$PREK_HOME/" || true
  done
fi
export AI_BACKBONE="$root"
export AI_BACKBONE_OFFLINE=1   # never reach GitHub or a registry from a test
# Python on Windows writes to a pipe in cp1252 and stops at the first letter
# outside it (Turkish ı, an arrow, an em dash). Recipes get UTF-8 from
# core.just; the suite starts python itself, including `python3 -c`.
export PYTHONUTF8=1
export PYTHONIOENCODING=utf-8
# Nor the real usage meter, the real transcripts or the real temp folder: the
# session line reads these (spec 014), and the budget section points them at its
# own fixtures. Until then: no meter, no transcripts, one quiet line.
export AI_BACKBONE_BUDGET_PROJECTS="$tmp/no-projects" AI_BACKBONE_BUDGET_METER="$tmp/no-meter" AI_BACKBONE_BUDGET_CACHE="$tmp/budget-cache.json"
# Nor the machine's shared upstream cache (spec 035). A copy under a day old
# there would make an offline check read as current. This folder starts empty.
export AI_BACKBONE_UPSTREAM_CACHE="$tmp/upstream-cache"
mkdir -p "$AI_BACKBONE_UPSTREAM_CACHE"
mkdir -p "$tmp/T"; export TMPDIR="$tmp/T"
# spec 041: no check calls the real keychain, Secret Service, DPAPI, or this
# machine's secret files. Recipes see a fake store and an empty home.
export AI_BACKBONE_KEYSTORE="$tmp/keystore"
mkdir -p "$AI_BACKBONE_KEYSTORE/items" "$AI_BACKBONE_KEYSTORE/reason"
export AI_BACKBONE_SECRET_HOME="$tmp/secret-home"
mkdir -p "$AI_BACKBONE_SECRET_HOME"
# Nor the projects next to the real backbone: doctor adds up their build caps,
# and a build's trim may go into their folders (spec 032).
export AI_BACKBONE_PROJECTS="$tmp/no-projects"
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
# A background job on Git Bash is often not reaped. `wait` with no pid, or
# `wait` on a killed job, or on a shell that started a native program, blocks
# until the lane's cap (spec 020). A wait names one pid. On Windows it is a
# poll with a bound, and a kill goes to the Windows process tree.
suite_winpid() {
  local pid=$1 w=""
  if [ -r "/proc/$pid/winpid" ]; then
    w=$(tr -cd '0-9' < "/proc/$pid/winpid" 2>/dev/null || true)
  fi
  printf '%s' "$w"
}
suite_alive() {
  local pid=$1 st
  kill -0 "$pid" 2>/dev/null || return 1
  if ! command -v cygpath >/dev/null 2>&1; then return 0; fi
  st=$(ps -p "$pid" -o stat= 2>/dev/null || true)
  st=${st//[[:space:]]/}
  case "$st" in
    Z*) return 1 ;;
    "") ps -p "$pid" >/dev/null 2>&1 || return 1 ;;
  esac
  return 0
}
suite_stop() {
  local pid=$1 w i
  case "$pid" in
    ""|*[!0-9]*) return 0 ;;
  esac
  if command -v cygpath >/dev/null 2>&1; then
    w=$(suite_winpid "$pid")
    if [ -n "$w" ]; then
      if command -v taskkill >/dev/null 2>&1; then
        taskkill //F //T //PID "$w" >/dev/null 2>&1 || true
      elif command -v taskkill.exe >/dev/null 2>&1; then
        taskkill.exe //F //T //PID "$w" >/dev/null 2>&1 || true
      fi
    fi
    kill -TERM "$pid" 2>/dev/null || true
    kill -KILL "$pid" 2>/dev/null || true
    i=0
    while suite_alive "$pid" && [ "$i" -lt 20 ]; do
      sleep 0.1
      i=$((i + 1))
    done
    return 0
  fi
  kill -TERM "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
  return 0
}
suite_wait() {
  local pid=$1 bound=${2:-60} i=0
  case "$pid" in
    ""|*[!0-9]*) return 0 ;;
  esac
  if ! command -v cygpath >/dev/null 2>&1; then
    wait "$pid" 2>/dev/null || true
    return 0
  fi
  while suite_alive "$pid" && [ "$i" -lt "$bound" ]; do
    sleep 1
    i=$((i + 1))
  done
  if suite_alive "$pid"; then suite_stop "$pid"; fi
  return 0
}
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
# The include also brings this machine's own caps for heavy work (spec 026), and
# a Mac that set them saw _heavy's checks fail. Read after the include, the empty
# values win; a check that wants a cap gives it itself. Trimming build output
# (spec 027) is off for the same reason, and the checks of it turn it on.
printf '[ai-backbone]\n\tjobs =\n\tnice =\n\tbuild-cap = off\n' >> "$GIT_CONFIG_GLOBAL"
# Nor this machine's builds (spec 015). A doctor run in a throwaway project with
# the Rust layer measures the build folder, and on a machine whose shell sets
# CARGO_TARGET_DIR that is every project's real one, hundreds of gigabytes. And
# a heavy recipe waits for a build already running, which on a machine where
# somebody is working is real: the suite would wait with them. The spec 015
# section sets each of these itself, with a fake ps.
# Nor the caps a save hands its checks, this suite among them, on a machine
# that set ai-backbone.jobs (spec 026): an inherited MAKEFLAGS is one _heavy
# leaves alone, and its checks read a different line.
unset CARGO_TARGET_DIR CARGO_BUILD_TARGET_DIR CARGO_BUILD_JOBS CARGO_PROFILE_DEV_DEBUG BUILD_OUTPUT_WARN_GB
unset RUST_TEST_THREADS CMAKE_BUILD_PARALLEL_LEVEL MAKEFLAGS
export BUILD_WAIT_MINUTES=0
# Nor this machine's build queue (spec 027): a real build waiting on this Mac
# would hold the suite's, and the suite's tickets would hold it.
export AI_BACKBONE_BUILD_QUEUE="$tmp/build-queue"
REAL_PS=$(command -v ps || echo /bin/ps); export REAL_PS
pass=0; fail=0
ok()    { pass=$((pass+1)); printf "  ok    %s\n" "$1"; }
bad()   { fail=$((fail+1)); printf "  FAIL  %s\n" "$1"; }
# How long each section took, slowest first at the end (spec 031): Windows ran
# the suite in 26 minutes against Linux's 4, and nothing said where they went.
sec_name="setup"; sec_start=$SECONDS; sec_times=""
section() { sec_times="$sec_times$((SECONDS-sec_start)) $sec_name"$'\n'; sec_name="$1"; sec_start=$SECONDS; echo "== $1 =="; }
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

# Windows runs three processes so the suite finishes inside its cap (spec 031).
# Linux and macOS leave the lane unset and run every section in one process.
# A section that needs files another section built stays in that section's lane.
lane_wants() {
  local id=$1
  case "${AI_BACKBONE_SUITE_LANE:-all}" in
    all) return 0 ;;
    rest)
      case "$id" in
        project|budget|save|clone|stable|session|radar|lint|plain|checks|build|flutter|ideas|notes|b27|b28) return 0 ;;
      esac
      return 1 ;;
    delegate) [ "$id" = delegate ]; return ;;
    win)
      case "$id" in
        budget|save|clone|stable|session|radar|lint|plain|checks|build|flutter|ideas|notes|b27|b28|delegate) return 1 ;;
      esac
      return 0 ;;
    *) printf 'unknown suite lane: %s\n' "${AI_BACKBONE_SUITE_LANE}" >&2; exit 2 ;;
  esac
}
py=$(just -f "$root/Justfile" _py)
# cargo-audit stand-in (n-2ed2cf). Python on Windows cannot CreateProcess a
# shell script (WinError 193), so there the scan is pointed at a .cmd that
# runs this script through bash. A real cargo-audit.exe is launched as itself.
install_audit_standin() {
  [ -n "${AI_BACKBONE_AUDIT_STANDIN:-}" ] && return 0
  export AI_BACKBONE_AUDIT_STANDIN=1
  mkdir -p "$tmp/bin"
  cat > "$tmp/cargo-audit-fake.py" << 'PY'
import json, os, sys
from importlib.util import module_from_spec, spec_from_file_location
from pathlib import Path
root = os.environ["AI_BACKBONE"]
spec = spec_from_file_location("upstream_audit", root + "/.ai-backbone/upstream.py")
mod = module_from_spec(spec)
spec.loader.exec_module(mod)
args = sys.argv[1:]
log = os.environ.get("AI_BACKBONE_CARGO_AUDIT_ARGV", "")
if log:
    with open(log, "a", encoding="utf-8") as fh:
        fh.write(" ".join(args) + "\n")
def opt(flag):
    if flag in args:
        i = args.index(flag)
        if i + 1 < len(args):
            return args[i + 1]
    return ""
lock, db = opt("--file"), opt("--db")
if not lock or not db:
    sys.stderr.write("cargo-audit: need --file and --db\n")
    sys.exit(2)
try:
    import tomllib
except ModuleNotFoundError:
    sys.stderr.write("tomllib missing\n")
    sys.exit(2)
found, warnings = [], {}
for name, ver in mod.cargo_locked(lock, tomllib):
    parsed = mod.semver(ver)
    if parsed is None:
        continue
    for adv in mod.adv_list(Path(db), name, tomllib):
        if any(mod.semver_matches(req, parsed) for req in adv["patched"] + adv["unaffected"]):
            continue
        block = {"advisory": {"id": adv["id"], "package": name, "title": adv["title"],
                              "aliases": adv["aliases"], "informational": adv["kind"] or None},
                 "versions": {"patched": adv["patched"], "unaffected": adv["unaffected"]},
                 "package": {"name": name, "version": ver}}
        if adv["kind"]:
            warnings.setdefault(adv["kind"], []).append(block)
        else:
            found.append(block)
json.dump({"vulnerabilities": {"count": len(found), "list": found}, "warnings": warnings}, sys.stdout)
PY
  cat > "$tmp/bin/cargo-audit" << EOF
#!/bin/sh
if [ "\$1" = "--version" ] || [ "\$1" = "-V" ]; then
  echo "cargo-audit 0.23.0"
  exit 0
fi
exec "$py" "$tmp/cargo-audit-fake.py" "\$@"
EOF
  chmod +x "$tmp/bin/cargo-audit"
  case ":$PATH:" in
    *":$tmp/bin:"*) ;;
    *) export PATH="$tmp/bin:$PATH" ;;
  esac
  if command -v cygpath >/dev/null 2>&1; then
    local bashw scriptw
    bashw=$(cygpath -w "$(command -v bash)")
    scriptw=$(cygpath -w "$tmp/bin/cargo-audit")
    # CRLF, and the exit code on its own line: %ERRORLEVEL% on the same line
    # is still the previous command (spec 020, the npm stand-in).
    printf '@echo off\r\n"%s" "%s" %%*\r\nset RC=%%ERRORLEVEL%%\r\nexit /b %%RC%%\r\n' "$bashw" "$scriptw" > "$tmp/bin/cargo-audit.cmd"
    export AI_BACKBONE_CARGO_AUDIT="$(winpath "$tmp/bin/cargo-audit.cmd")"
  else
    export AI_BACKBONE_CARGO_AUDIT="$tmp/bin/cargo-audit"
  fi
}
case "${AI_BACKBONE_SUITE_LANE:-all}" in
  all) ;;
  *) printf 'Windows lane: %s (spec 031). Linux and macOS run every section in one process.\n' "$AI_BACKBONE_SUITE_LANE" ;;
esac

if lane_wants suite; then
section "the suite itself"
# The guard for the line above: a pipe into grep anywhere here is the race back.
check "an unset lane runs every section, and the three Windows lanes share the work" \
  "( unset AI_BACKBONE_SUITE_LANE; lane_wants suite && lane_wants delegate && lane_wants budget ) && ( export AI_BACKBONE_SUITE_LANE=win; lane_wants keystore && lane_wants project && lane_wants advisory && ! lane_wants budget && ! lane_wants delegate ) && ( export AI_BACKBONE_SUITE_LANE=rest; lane_wants lint && lane_wants project && lane_wants plain && lane_wants checks && ! lane_wants keystore && ! lane_wants advisory ) && ( export AI_BACKBONE_SUITE_LANE=delegate; lane_wants delegate && ! lane_wants budget && ! lane_wants keystore ) && { ( export AI_BACKBONE_SUITE_LANE=nope; lane_wants suite ); [ \$? -eq 2 ]; }"
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

fi
if lane_wants setup; then
section "setup.sh"
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

fi
if lane_wants project; then
section "a new project"
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
# 59 since 3.32.0: the team (spec 025), four role skills and the marketer's four
# references, each with its copy for Claude Code; the maintainer raised it on
# 2026-10-01 in an attended session, choosing separate references over one file.
# 60 since spec 027: buildtrim.py, which keeps a Rust build folder under its cap;
# the maintainer approved the spec that names it on 2026-10-10, attended.
# 61 since 3.41.3: .claude/skills/.ai-backbone-owned, the record of which skill
# copies sync-rules wrote (spec 033). Raised in the attended session of
# 2026-10-19, when that task was started.
# 63 since spec 034: the delegate skill and the Claude Code copy sync-rules
# writes. The maintainer approved that spec on 2026-10-20.
# 65 since the design skill: the skill and the Claude Code copy sync-rules
# writes. The maintainer approved that skill on 2026-10-30.
# 66 since spec 041: keystore.sh reaches every project. The maintainer
# approved that spec on 2026-10-31.
# 67 since spec 043: freshness-sweep.sh reaches every project (n-058e8b).
# The owner asked for the sweep on 2026-11-11.
# 68 since the vault sweep: vault-sweep.sh reaches every project (n-a931f8).
# The owner asked for the desk copy on 2026-11-12.
check "tracked files at most 68 (got $n)"             "[ $n -le 68 ]"
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
# 40 since 3.29.0: `just project-note` (spec 022), which the maintainer asked
# for by name in the batch of 2026-09-28, in an attended session. 41 since spec
# 027: `just trim-build`, named in the spec the maintainer approved on 2026-10-10
# in an attended session; in the core, so that the disk warning every project
# can show points at a recipe every project has.
# 45 since spec 034: `just delegate`, `delegate-status`, `delegate-accept` and
# `delegate-drop`, named in the spec the maintainer approved on 2026-10-20.
# 47 since spec 036: `just secrets-to-brain` and `just secrets-back`, named in
# the spec the maintainer approved on 2026-10-21.
# 49 since spec 041: `just with-secret` and `just secrets-to-keystore`, named
# in the spec the maintainer approved on 2026-10-31.
# 52 since spec 043: `just freshness-sweep`, `freshness-sweep-install` and
# `freshness-sweep-remove` (n-058e8b). The owner asked for them on 2026-11-11.
# 55 since the vault sweep: `just vault-sweep`, `vault-sweep-install` and
# `vault-sweep-remove` (n-a931f8). The owner asked for them on 2026-11-12.
check "recipes a new project shows at most 55 (got $r)" "[ $r -le 55 ]"
b=$(wc -c < AGENTS.md | tr -d ' ')
# 7080 since the design line (the maintainer, 2026-10-30): code follows the
# design skill, and a review cites its rule numbers. 7088 since spec 040:
# the worker line names kimi. 7210 since spec 041: the secrets rule names
# the keystore. The maintainer approved that spec on 2026-10-31. The
# session-load ceiling below is this file in a new project (the name
# Deneme Projesi is three bytes longer than ai-backbone) plus the 11-byte
# CLAUDE.md pointer.
check "AGENTS.md at most 7210 bytes (got $b)"         "[ $b -le 7210 ]"
# What a Claude Code session loads, not one file (spec 022): since 2.1.281 its
# large-instructions notice counts the instruction files together, @-imports
# included. Read the way the docs say Claude Code reads them (memory.md, read
# 2026-09-28): an @path outside code spans and fences, relative to the file
# that holds it, four hops deep at most, and a file already loaded not read
# again, so AGENTS.md counts once. The docs publish no number for the notice
# (it scales with the model's context window, CHANGELOG 2.1.169) and ask for
# under 200 lines per CLAUDE.md; the whole is held to that, and to AGENTS.md's
# own byte ceiling with room for the one-line pointer that imports it.
loaded() { perl -MCwd=abs_path -e '
  my (%seen, $bytes, $lines, $files);
  sub load { my ($f, $d) = @_; return if $d > 4; my $a = abs_path($f); return unless defined $a && -f $a;
    return if $seen{$a}++; open(my $h, "<", $a) or return; local $/; my $t = <$h>; close $h;
    $bytes += length($t); $lines += ($t =~ tr/\n//); $files++;
    (my $u = $t) =~ s/^```.*?^```//msg; $u =~ s/`[^`\n]*`//g;
    (my $dir = $a) =~ s{/[^/]*$}{};
    while ($u =~ /(?:^|\s)@([^\s`]+)/g) { my $p = $1; next if $p =~ m{^~}; load($p =~ m{^/} ? $p : "$dir/$p", $d + 1) } }
  load($_, 0) for @ARGV; print "$bytes $lines $files\n";' "$@"; }
read -r lb ll lf <<<"$(loaded CLAUDE.md AGENTS.md)"
check "what a session loads through CLAUDE.md, AGENTS.md once: at most 7221 bytes and 200 lines (got $lb bytes, $ll lines, $lf files)" "[ '$lf' = 2 ] && [ $lb -le 7221 ] && [ $ll -le 200 ]"
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
check "the session skill names three public standards by their address" "grep -q 'https://calver.org' $std && grep -q 'https://keepachangelog.com' $std && grep -q 'https://www.conventionalcommits.org' $std && grep -q 'YY\\.M\\.PATCH' $std"
kinds_named() {
  local k n=0
  for k in $(grep -m1 -oE '\^\(feat[a-z|]*\)' "$root/.ai-backbone/core.just" | tr -d '^()' | tr '|' ' '); do
    grep -qF "\`$k\`" "$std" || return 1; n=$((n+1))
  done
  [ "$n" -ge 5 ]
}
check "and every kind of commit message that save accepts" "kinds_named"
check "the spec skill asks for a question that carries its answer" "grep -q 'the answer you would give' .agents/skills/spec/SKILL.md && grep -q 'each with the answer you' .ai-backbone/templates/spec.md"
# Spec 025: a role is a skill with seven parts, so an agent with no skill
# support follows it by reading the file, and the team skill lists every role
# the backbone ships. A new project carries them, and Claude Code gets copies.
role_parts() {
  local r p
  for r in research data marketing; do
    case "$(sed -n 3p ".agents/skills/$r/SKILL.md")" in "description: The "*" role. "*) ;; *) echo "$r: description"; return 1 ;; esac
    grep -qF "| \`$r\` |" .agents/skills/team/SKILL.md || { echo "$r: not in the roster"; return 1; }
    for p in When Inputs Steps Output Done Handover Never; do grep -qx "## $p" ".agents/skills/$r/SKILL.md" || { echo "$r: ## $p"; return 1; }; done
  done
}
check "every role skill has the seven parts, and the team skill lists it" "role_parts"
check "a new project gets the team, copied for Claude Code, and a place for marketing" "[ -f .claude/skills/team/SKILL.md ] && [ -f .claude/skills/marketing/references/launch.md ] && [ -d brain/06-marketing ]"
# The design skill ships with the backbone. Front matter is the block between
# the first two lines that are exactly ---; name and description must both parse.
design_front() {
  awk '
    NR == 1 { if ($0 != "---") bad = 1; next }
    $0 == "---" { closed = 1; exit }
    /^name:/ { sub(/^name:[ \t]*/, ""); gsub(/["\r]/, ""); sub(/[ \t]+$/, ""); name = $0; next }
    /^description:/ { sub(/^description:[ \t]*/, ""); sub(/^[ \t]+/, ""); sub(/[ \t]+$/, ""); desc = $0; next }
    END { if (bad || !closed || name != "design" || length(desc) == 0) exit 1 }
  ' .agents/skills/design/SKILL.md
}
check "the design skill is present, its front matter parses, and a new project receives it" "[ -f '$root/.agents/skills/design/SKILL.md' ] && [ -f .agents/skills/design/SKILL.md ] && [ -f .claude/skills/design/SKILL.md ] && cmp -s '$root/.agents/skills/design/SKILL.md' .agents/skills/design/SKILL.md && cmp -s .agents/skills/design/SKILL.md .claude/skills/design/SKILL.md && design_front && grep -q '^design ' .claude/skills/.ai-backbone-owned && grep -qx -- '- Code follows the design skill. A review cites its rule numbers.' AGENTS.md"
# OpenSpec 1.13.2 (PR #1955): each task group lands the tests and docs its own
# work calls for, and no final group gathers them. Ours adds the lesson of spec
# 012, whose last box also waited for a radar day: a step that waits on
# something later is a box of its own (spec 022).
check "a task carries its own tests and docs, and a wait is a box of its own" "grep -q 'with its own tests and docs' .ai-backbone/templates/spec.md && grep -q 'never into a last' .agents/skills/spec/SKILL.md && grep -q 'is a box of its own' .agents/skills/spec/SKILL.md && grep -q 'never into a last one that gathers them' .agents/skills/backbone-dev/SKILL.md"
check "the ADR template takes no 'from memory' after Nothing" "grep -q 'is never the reason' .ai-backbone/templates/adr.md"
# The project brief learned what the backbone's own learned in 3.21.0: a pasted
# brief is a second truth, a checkout with no branch refuses `git push origin
# HEAD` (measured on git 2.55.0: "not a full refname"), and a push GitHub refuses
# because it moved has an answer. The pointer it offers a scheduler rests on
# `routine.sh --brief` naming a file that begins "# Routine", so that is run.
check "the project brief is pointed at, never pasted"  "brief13=\$(sh .ai-backbone/routine.sh --brief) && case \"\$(head -1 \"\$brief13\")\" in '# Routine'*) grep -q 'routine.sh --brief' \"\$brief13\" && ! grep -qi 'paste it as the prompt' \"\$brief13\" ;; *) false ;; esac"
check "and says what to do with no branch, and with a push GitHub refuses" "grep -q 'git push origin HEAD:<branch>' .ai-backbone/templates/routine-project.md && grep -q 'git pull --rebase origin <branch>' .ai-backbone/templates/routine-project.md && grep -q 'git rebase --abort' .ai-backbone/templates/routine-project.md"
# The spec skill makes a step that waits on the maintainer a box of its own, so
# the Tasks list holds boxes no unattended run may take ("walk the acceptance
# list with the owner", a measurement on a machine it is not on). The project
# brief took the oldest unticked one whatever it said; now it skips such a box,
# names it in the report, and says so when a spec has none left that is its own.
check "the project brief leaves a task that waits on a person to the person" "grep -q 'is not yours' .ai-backbone/templates/routine-project.md && grep -q 'nothing approved to do that an unattended run may take' .ai-backbone/templates/routine-project.md && grep -q 'Never tick a box you did not do' .ai-backbone/templates/routine-project.md"
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
# It said "this is 3.27.2" for fifteen days and 107 versions (spec 031).
v=$(sed -n '1s/.*version \([0-9][0-9.]*\).*/\1/p' "$root/.ai-backbone/core.just")
other_versions() { V="$1" perl -ne 'while (/(?<![0-9.])(\d+\.\d+\.\d+)(?![0-9])/g) { print "$1\n" if $1 ne $ENV{V} }' "$2"; }
printf 'this is 3.27.2, and %s\n' "$v" > "$tmp/readme-old.md"
check "doctor in the backbone says the share of comment lines in core.just, and the skill the rule" "says '^  ok    core.just: [0-9]+ lines, [0-9]+ of them comments \([0-9]+%\)' env JUST_JUSTFILE='$root/Justfile' JUST_WORKING_DIRECTORY='$root' just doctor && grep -q 'says what the code guards and which' '$root/.agents/skills/backbone-dev/SKILL.md' && grep -q 'never a .Path.' '$root/.agents/skills/backbone-dev/SKILL.md'"
check "README names no version, or only the one on line 1 of core.just" "[ -z \"\$(other_versions '$v' '$root/README.md')\" ] && [ \"\$(other_versions '$v' '$tmp/readme-old.md')\" = 3.27.2 ]"
# 3.22.0 gave the scheduled agent a Sunday of its own and left the pages that
# describe that agent as they were. The picture above draws the radar, so the
# words beside it must exist too.
check "the docs say what the scheduled agent does on a radar run" "grep -q 'radar.toml' '$root/docs/01-getting-started.md' && grep -q 'radar.toml' '$root/docs/README.md'"
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
fi
if lane_wants budget; then
section "the budget"
bt="$tmp/budget"; mkdir -p "$bt/projects/p1/s1/subagents" "$bt/home"
py=$(just _py); nowz=$(date -u +%Y-%m-%dT%H:%M:%S.000Z)
# The win lane skips this section, so the gate section installs it too.
install_audit_standin
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
check "and both refusals say a mode is not a yes to a count (spec 031)" "says 'a mode they turned on is not a yes to a count' hcall s9 Agent t9 && says 'a mode they turned on is not a yes to a count' hcall s9 Workflow w1"
check "the audit skill says it too"                     "grep -q 'is not a yes to a number' '$root/.agents/skills/audit/SKILL.md'"
check "the yes lifts the cap for that session only"     "just _agent-cap 12 '$hk/ai-backbone-agents/s9' >/dev/null && [ -z \"\$(hcall s9 Agent t10)\" ] && [ -z \"\$(hcall s9 Workflow w3)\" ] && says '\"deny\"' hcall s9 Workflow w4 || true; [ -f '$hk/ai-backbone-agents/s9/cap' ]"
check "a refused call is not counted"                    "[ \$(wc -l < '$hk/ai-backbone-agents/s9/started' | tr -d ' ') -eq 9 ]"
check "no usable session id: neither counted nor blocked" "[ -z \"\$(printf '{\"tool_name\":\"Agent\"}' | env TMPDIR='$hk' bash '$root/.ai-backbone/agent-cap.sh')\" ]"
check "_agent-cap refuses what is not a number or not a session folder" "! just _agent-cap x '$hk/ai-backbone-agents/s9' && ! just _agent-cap 5 '$hk/elsewhere'"
# The hook into a project's settings, merged, once, and out again.
sj="$tmp/hook/settings.json"; cp "$root/.claude/settings.json" "$sj"
check "the hook is removed and added back without touching the rest" "[ \"\$('$py' '$root/.ai-backbone/budget.py' hook remove '$sj')\" = removed ] && ! grep -q agent-cap '$sj' && grep -q 'session-start' '$sj' && [ \"\$('$py' '$root/.ai-backbone/budget.py' hook add '$sj')\" = added ] && [ \"\$('$py' '$root/.ai-backbone/budget.py' hook add '$sj')\" = 'already there' ] && '$py' '$root/.ai-backbone/budget.py' hook check '$sj' && cmp -s '$sj' '$root/.claude/settings.json'"
# n-a931f8. The hourly copy is not part of the cap. hook add must not write it,
# and once it is there a cap round trip puts the file back byte for byte: that
# is what keeps a later save on a clean tree from seeing .claude/settings.json.
cp "$root/.claude/settings.json" "$tmp/hook/vault.json"
check "the hourly vault hooks are their own install, and the cap round trip leaves them" "[ \"\$('$py' '$root/.ai-backbone/budget.py' vault add '$tmp/hook/vault.json')\" = added ] && '$py' '$root/.ai-backbone/budget.py' vault check '$tmp/hook/vault.json' && '$py' -c \"import json,sys; d=json.load(open(sys.argv[1])); ss=[h['command'] for h in d['hooks']['SessionStart'][0]['hooks']]; assert ss[0].startswith('just session-start') and any('_vault-copy hourly' in c for c in ss); pu=d['hooks']['PostToolUse'][0]; assert pu['matcher']=='Bash' and '_vault-copy hourly' in pu['hooks'][0]['command']; assert d['hooks']['PreToolUse'][0]['matcher']=='Agent|Workflow'\" '$tmp/hook/vault.json' && cp '$tmp/hook/vault.json' '$tmp/hook/vault.golden' && [ \"\$('$py' '$root/.ai-backbone/budget.py' vault add '$tmp/hook/vault.json')\" = 'already there' ] && cmp -s '$tmp/hook/vault.json' '$tmp/hook/vault.golden' && '$py' '$root/.ai-backbone/budget.py' hook remove '$tmp/hook/vault.json' >/dev/null && '$py' '$root/.ai-backbone/budget.py' hook add '$tmp/hook/vault.json' >/dev/null && cmp -s '$tmp/hook/vault.json' '$tmp/hook/vault.golden' && [ \"\$('$py' '$root/.ai-backbone/budget.py' vault remove '$tmp/hook/vault.json')\" = removed ] && cmp -s '$tmp/hook/vault.json' '$root/.claude/settings.json' && [ \"\$('$py' '$root/.ai-backbone/budget.py' vault remove '$tmp/hook/vault.json')\" = 'not there' ] && cmp -s '$sj' '$root/.claude/settings.json'"
# n-a931f8. The desk sweep is a third action. hook add and vault add must not
# write it, and a round trip of each puts the file back. The seed is written
# the way budget.py saves, so the bytes can match.
"$py" - "$tmp/hook/sweep.json" <<'PYEOF'
import json, sys
data = {
  "hooks": {
    "SessionStart": [{"hooks": [{"type": "command", "command": "just session-start"}]}],
    "PreToolUse": [{"matcher": "Agent|Workflow", "hooks": [{"type": "command", "command": 'bash "$CLAUDE_PROJECT_DIR"/.ai-backbone/agent-cap.sh'}]}],
    "PostToolUse": [{"matcher": "Bash", "hooks": [{"type": "command", "command": "echo stranger-post"}]}],
    "Stop": [{"hooks": [{"type": "command", "command": "echo stranger-stop"}]}],
  },
  "permissions": {"allow": ["Bash(just mine:*)"]},
}
with open(sys.argv[1], "w", encoding="utf-8", newline="\n") as fh:
    json.dump(data, fh, indent=2, ensure_ascii=False)
    fh.write("\n")
PYEOF
cp "$tmp/hook/sweep.json" "$tmp/hook/sweep.orig"
vault_sweep_hooks_round() {
  local sj="$tmp/hook/sweep.json" cmd
  cmd='bash "/tmp/vault-sweep.sh" --periodic "/tmp/bb" >/dev/null 2>&1 || true'
  [ "$("$py" "$root/.ai-backbone/budget.py" sweep add "$sj" "$cmd")" = added ] || return 1
  "$py" "$root/.ai-backbone/budget.py" sweep check "$sj" || return 1
  grep -q 'echo stranger-stop' "$sj" || return 1
  grep -q 'echo stranger-post' "$sj" || return 1
  grep -q 'Bash(just mine:\*)' "$sj" || return 1
  grep -q 'agent-cap.sh' "$sj" || return 1
  cp "$sj" "$tmp/hook/sweep.golden"
  [ "$("$py" "$root/.ai-backbone/budget.py" sweep add "$sj" "$cmd")" = "already there" ] || return 1
  cmp -s "$sj" "$tmp/hook/sweep.golden" || return 1
  "$py" "$root/.ai-backbone/budget.py" vault add "$sj" >/dev/null || return 1
  "$py" "$root/.ai-backbone/budget.py" vault remove "$sj" >/dev/null || return 1
  cmp -s "$sj" "$tmp/hook/sweep.golden" || { echo "vault round trip moved the sweep"; diff -u "$tmp/hook/sweep.golden" "$sj"; return 1; }
  "$py" "$root/.ai-backbone/budget.py" hook remove "$sj" >/dev/null || return 1
  "$py" "$root/.ai-backbone/budget.py" sweep check "$sj" || { echo "hook remove took the sweep"; return 1; }
  "$py" "$root/.ai-backbone/budget.py" hook add "$sj" >/dev/null || return 1
  cmp -s "$sj" "$tmp/hook/sweep.golden" || { echo "cap round trip moved the sweep"; diff -u "$tmp/hook/sweep.golden" "$sj"; return 1; }
  [ "$("$py" "$root/.ai-backbone/budget.py" sweep remove "$sj")" = removed ] || return 1
  cmp -s "$sj" "$tmp/hook/sweep.orig" || { echo "sweep remove did not restore"; diff -u "$tmp/hook/sweep.orig" "$sj"; return 1; }
  [ "$("$py" "$root/.ai-backbone/budget.py" sweep remove "$sj")" = "not there" ] || return 1
  if "$py" "$root/.ai-backbone/budget.py" sweep add "$sj" "just something" >/dev/null 2>&1; then
    echo "a command without the marker was accepted"
    return 1
  fi
  cmp -s "$sj" "$tmp/hook/sweep.orig" || return 1
}
check "the desk sweep hooks round-trip and leave the cap, the hourly copy and a stranger's hook" "vault_sweep_hooks_round"
"$py" - "$tmp/hook/two.json" <<'PYEOF'
import json,sys; g=lambda m:{"matcher":m,"hooks":[{"type":"command","command":'bash "$CLAUDE_PROJECT_DIR"/.ai-backbone/agent-cap.sh'}]}; json.dump({"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"true"}]},g("Agent"),g("Agent|Workflow")]}},open(sys.argv[1],"w"))
PYEOF
check "two copies of the hook become one, beside a stranger's group" "[ \"\$('$py' '$root/.ai-backbone/budget.py' hook add '$tmp/hook/two.json')\" = updated ] && '$py' -c \"import json,sys;g=json.load(open(sys.argv[1]))['hooks']['PreToolUse'];assert [x['matcher'] for x in g]==['Bash','Agent|Workflow'],g\" '$tmp/hook/two.json'"
printf '{ // a comment\n  "hooks": {} }\n' > "$tmp/hook/jsonc.json"
check "a settings file that is not plain JSON is left alone and said" "! '$py' '$root/.ai-backbone/budget.py' hook add '$tmp/hook/jsonc.json' 2>/dev/null && grep -q '// a comment' '$tmp/hook/jsonc.json'"
check "the same call counted once, however many times the hook sees it" "hcall s9 Agent t10 >/dev/null; hcall s9 Agent t10 >/dev/null; [ \$(grep -c '^t10\$' '$hk/ai-backbone-agents/s9/started') -eq 1 ]"
# Twelve at once, the shape of an audit's lenses: eight pass, four are refused.
cap_pids=""
for i in $(seq 1 12); do
  ( hcall s12 Agent p$i > "$hk/p$i.out" 2>&1 ) &
  cap_pids="$cap_pids $!"
done
for cap_pid in $cap_pids; do suite_wait "$cap_pid" 60; done
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
# Spec 031: nothing throws work away unasked; the list guards habits, not a boundary.
check "the seed does not allow git checkout -- ., and denies the other rm spellings" "! grep -qF 'git checkout -- .' '$root/.claude/settings.json' && grep -qF 'Bash(rm -fr:*)' '$root/.claude/settings.json' && grep -qF 'Bash(rm -r -f:*)' '$root/.claude/settings.json' && grep -q 'It is not a security boundary' '$root/docs/how-it-works.md'"
# n-cdb28d. .claude/settings.json is a seed, then the project's. The four
# delegation rules are merged when WORKER is set. A rule the project wrote stays.
da="$tmp/delegate-allow"; mkdir -p "$da"
"$py" - "$da/own.json" <<'PYEOF'
import json, sys
json.dump({"permissions": {"allow": ["Bash(just mine:*)"], "deny": ["Bash(sudo:*)"]}, "kept": True}, open(sys.argv[1], "w"), indent=2)
open(sys.argv[1], "a").write("\n")
PYEOF
cp "$da/own.json" "$da/off.json"
check "WORKER unset or off adds no delegation rule and does not rewrite the file" "[ \"\$(env -u WORKER '$py' '$root/.ai-backbone/budget.py' allow '$da/off.json')\" = off ] && [ \"\$(env WORKER=off '$py' '$root/.ai-backbone/budget.py' allow '$da/off.json')\" = off ] && [ \"\$(env WORKER=other '$py' '$root/.ai-backbone/budget.py' allow '$da/off.json')\" = off ] && cmp -s '$da/own.json' '$da/off.json'"
check "the four delegation rules are added once, behind a rule the project wrote" "[ \"\$(env WORKER=grok '$py' '$root/.ai-backbone/budget.py' allow '$da/own.json')\" = added ] && [ \"\$(env WORKER=claude '$py' '$root/.ai-backbone/budget.py' allow '$da/own.json')\" = 'already there' ] && '$py' -c \"import json,sys; d=json.load(open(sys.argv[1])); a=d['permissions']['allow']; assert a==['Bash(just mine:*)','Bash(just delegate:*)','Bash(just delegate-status:*)','Bash(just delegate-accept:*)','Bash(just delegate-drop:*)'], a; assert d['permissions']['deny']==['Bash(sudo:*)'] and d['kept'] is True\" '$da/own.json'"
cp "$da/off.json" "$da/kimi.json"
check "WORKER=kimi adds the same four delegation rules" "[ \"\$(env WORKER=kimi '$py' '$root/.ai-backbone/budget.py' allow '$da/kimi.json')\" = added ] && '$py' -c \"import json,sys; a=json.load(open(sys.argv[1]))['permissions']['allow']; assert a.count('Bash(just delegate:*)')==1 and 'Bash(just delegate-drop:*)' in a\" '$da/kimi.json'"
printf '{ // comment\n}\n' > "$da/bad.json"
check "a settings file that is not plain JSON is left alone when the delegation rules are asked for" "! env WORKER=grok '$py' '$root/.ai-backbone/budget.py' allow '$da/bad.json' >/dev/null && grep -q '// comment' '$da/bad.json'"
printf '{"permissions":{"allow":"Bash(just mine:*)"}}\n' > "$da/str.json"
check "an allow value that is not a list is left alone" "! env WORKER=grok '$py' '$root/.ai-backbone/budget.py' allow '$da/str.json' >/dev/null && grep -q 'Bash(just mine:' '$da/str.json' && ! grep -q 'just delegate:' '$da/str.json'"
check "the seed does not list the delegation rules" "! grep -qF 'Bash(just delegate:*)' '$root/.claude/settings.json' && grep -q 'just delegate-drop' '$root/docs/how-it-works.md' && grep -q n-cdb28d '$root/CHANGELOG.md' && ! grep -q n-cdb28d '$root/docs/backlog.md'"
if ( cd "$root" && env -u WORKER just new-project "$tmp/deleg-old" ) >/dev/null 2>&1; then ok "a project made with delegation off"; else bad "a project made with delegation off"; fi
check "that project has no delegation allow rule yet" "! grep -qF 'Bash(just delegate:*)' '$tmp/deleg-old/.claude/settings.json' && grep -qF 'Bash(just:*)' '$tmp/deleg-old/.claude/settings.json' && ! grep -qF 'find-generic-password' '$tmp/deleg-old/.claude/settings.json'"
"$py" - "$tmp/deleg-old/.claude/settings.json" <<'PYEOF'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
d["permissions"]["allow"].insert(0, "Bash(just mine:*)")
json.dump(d, open(p, "w"), indent=2)
open(p, "a").write("\n")
PYEOF
check "template-update with WORKER set adds the four rules and keeps the project's" "upd=\$(cd '$tmp/deleg-old' && env WORKER=opencode just template-update 2>&1) && grep -q 'may run just delegate' <<<\"\$upd\" && '$py' -c \"import json,sys; d=json.load(open(sys.argv[1])); a=d['permissions']['allow']; assert a[0]=='Bash(just mine:*)', a; assert a.count('Bash(just delegate:*)')==1; assert 'Bash(just delegate-status:*)' in a and 'Bash(just delegate-accept:*)' in a and 'Bash(just delegate-drop:*)' in a; assert 'Bash(just:*)' in a; assert 'Bash(sudo:*)' in d['permissions']['deny']\" '$tmp/deleg-old/.claude/settings.json' && upd2=\$(cd '$tmp/deleg-old' && env WORKER=grok just template-update 2>&1) && ! grep -q 'may run just delegate' <<<\"\$upd2\" && '$py' -c \"import json,sys; a=json.load(open(sys.argv[1]))['permissions']['allow']; assert a.count('Bash(just delegate:*)')==1 and a.count('Bash(just mine:*)')==1\" '$tmp/deleg-old/.claude/settings.json'"
check "that update also merges the keystore denies once and keeps the rule already there" "'$py' -c \"import json,sys; d=json.load(open(sys.argv[1])); n=d['permissions']['deny']; assert n.count('Bash(sudo:*)')==1; assert n.count('Bash(security find-generic-password:*)')==1; assert n.count('Bash(ssh-add:*)')==1; assert n.count('Read(**/.env)')==1; assert n.count('Read(**/ssh-agent.sock)')==1; assert 'Read(**/.env.example)' not in n; blob=open(sys.argv[1]).read(); assert '/Users/' not in blob and 'home/' not in blob\" '$tmp/deleg-old/.claude/settings.json'"
if ( cd "$root" && env WORKER=claude just new-project "$tmp/deleg-fresh" ) >/dev/null 2>&1; then ok "a fresh project with WORKER set"; else bad "a fresh project with WORKER set"; fi
check "a fresh project gets the four rules and keeps the seed's" "'$py' -c \"import json,sys; d=json.load(open(sys.argv[1])); a=d['permissions']['allow']; assert 'Bash(just:*)' in a and a.count('Bash(just delegate:*)')==1 and 'Bash(just delegate-status:*)' in a and 'Bash(just delegate-accept:*)' in a and 'Bash(just delegate-drop:*)' in a; assert 'Bash(sudo:*)' in d['permissions']['deny']\" '$tmp/deleg-fresh/.claude/settings.json'"
# Claude Code's skills are copies, never links: Git for Windows checks a link out
# as a text file naming its target, and Claude Code found no skills (spec 020).
check "a new project's skills are copies Claude Code reads on any machine" "[ -f .claude/skills/session/SKILL.md ] && [ ! -L .claude/skills/session ] && just _rules-check"
echo 'an edit' >> .claude/skills/spec/SKILL.md
check "an edited generated skill copy is named and kept" "says 'kept .claude/skills/spec \\(edited since it was generated\\)' just sync-rules && grep -q 'an edit' .claude/skills/spec/SKILL.md && just _rules-check"
rm -rf .claude/skills/spec && cp -R .agents/skills/spec .claude/skills/spec && just sync-rules >/dev/null
mv .agents/skills/audit .agents/skills/audit-renamed
check "renaming a skill drops the old generated copy and writes the new one" "just sync-rules >/dev/null && [ ! -d .claude/skills/audit ] && diff -rq .agents/skills/audit-renamed .claude/skills/audit-renamed"
mv .agents/skills/audit-renamed .agents/skills/audit
rm -rf .claude/skills/audit-renamed && just sync-rules >/dev/null
rm -rf .agents/skills/audit
check "sync-rules removes a generated copy whose source is gone" "says 'removed .claude/skills/audit' just sync-rules && [ ! -d .claude/skills/audit ]"
mkdir -p .agents/skills/audit && cp -R "$root/.agents/skills/audit/." .agents/skills/audit/ && just sync-rules >/dev/null
mkdir -p .claude/skills/mine && printf 'project skill\n' > .claude/skills/mine/SKILL.md
cp .claude/settings.json "$tmp/settings-before-sync"
check "an unrecorded skill copy and settings.json survive sync" "says 'kept .claude/skills/mine' just sync-rules && grep -q 'project skill' .claude/skills/mine/SKILL.md && cmp -s .claude/settings.json '$tmp/settings-before-sync'"
rm -rf .claude/skills/mine && just sync-rules >/dev/null
before=$(find .claude/skills -type f | sort | xargs cksum)
check "a second sync-rules changes no skill copy" "just sync-rules >/dev/null && [ \"\$before\" = \"\$(find .claude/skills -type f | sort | xargs cksum)\" ]"
cp AGENTS.md "$tmp/agents-tools"
perl -pi -e 's/^\| tools \| claude \|/| tools | cursor |/' AGENTS.md
check "dropping claude from tools removes generated copies and leaves a project skill" "mkdir -p .claude/skills/mine && printf 'stay\n' > .claude/skills/mine/SKILL.md && says 'removed .claude/skills/session' just sync-rules && [ ! -d .claude/skills/session ] && [ -d .agents/skills/session ] && grep -q stay .claude/skills/mine/SKILL.md && cmp -s .claude/settings.json '$tmp/settings-before-sync'"
cp "$tmp/agents-tools" AGENTS.md
rm -rf .claude/skills/mine && just sync-rules >/dev/null
rm -rf .claude/skills/spec; ln -s ../../.agents/skills/spec .claude/skills/spec
cp .agents/skills/spec/SKILL.md "$tmp/spec-skill-before"
check "sync-rules turns an older project's link into a copy, and writes nothing through it" "just sync-rules >/dev/null && [ ! -L .claude/skills/spec ] && diff -r .agents/skills/spec .claude/skills/spec && cmp -s .agents/skills/spec/SKILL.md '$tmp/spec-skill-before' && just _rules-check"
# A copy an earlier version of sync-rules wrote was never recorded, so it stayed
# frozen at its old version while .agents/skills moved on (n-939129). Its own
# history says what it is: here, a version the backbone shipped, then a save
# that is a backbone update. A copy matching neither, last touched by an
# ordinary save, is still the person's and is kept.
ad="$tmp/adopt"
( cd "$root" && just new-project "$ad" ) >/dev/null 2>&1
cd "$ad" || exit 1
printf 'an older version\n' >> .agents/skills/session/SKILL.md
cp -R .agents/skills/session/. .claude/skills/session/
perl -ni -e 'print unless /^session /' .claude/skills/.ai-backbone-owned
git add -A >/dev/null 2>&1; git commit -qm "docs: an old copy" --no-verify >/dev/null 2>&1
cp -R "$root/.agents/skills/session/." .agents/skills/session/
git add -A >/dev/null 2>&1; git commit -qm "docs: the backbone arrives" --no-verify >/dev/null 2>&1
check "a committed copy that is a version the backbone shipped is adopted and brought level" "says 'copied .claude/skills/session \\(an earlier version left it, adopted\\)' just sync-rules && diff -rq .agents/skills/session .claude/skills/session && grep -q '^session ' .claude/skills/.ai-backbone-owned && just _rules-check"
printf 'edited by an old backbone\n' >> .claude/skills/spec/SKILL.md
perl -ni -e 'print unless /^spec /' .claude/skills/.ai-backbone-owned
git add -A >/dev/null 2>&1; git commit -qm "chore: backbone 3.40.0" --no-verify >/dev/null 2>&1
check "and one whose last save is a backbone update, though no version of the source matches it" "says 'copied .claude/skills/spec \\(an earlier version left it, adopted\\)' just sync-rules && diff -rq .agents/skills/spec .claude/skills/spec && grep -q '^spec ' .claude/skills/.ai-backbone-owned"
printf 'someone edited this copy\n' >> .claude/skills/team/SKILL.md
perl -ni -e 'print unless /^team /' .claude/skills/.ai-backbone-owned
git add -A >/dev/null 2>&1; git commit -qm "docs: a copy somebody edited" --no-verify >/dev/null 2>&1
check "but one matching no shipped version, last touched by an ordinary save, is kept" "says 'kept .claude/skills/team \\(not a recorded generated copy\\)' just sync-rules && grep -q 'someone edited this copy' .claude/skills/team/SKILL.md"
cd "$p" || exit 1

check "what python leaves behind is never saved"      "[ -z \"\$(git status --porcelain --untracked-files=all -- .ai-backbone/__pycache__)\" ] && git check-ignore -q .ai-backbone/__pycache__/upstream.cpython-311.pyc"
check "LICENSE names the maker, not the backbone"     "! grep -qF \"\$(sed -n 's/^Copyright (c) [0-9]* //p' '$root/LICENSE')\" LICENSE"
check "both git hooks installed"                      "[ -f .git/hooks/pre-commit ] && [ -f .git/hooks/commit-msg ]"
check "plain just shows the save command"             "says 'just save' just"
check "save on a clean tree is calm"                  "says 'Nothing new to save|yeni bir şey yok' just save x"
check "spec name becomes a slug"                      "just spec 'İlk Fikir' && [ -f docs/specs/001-ilk-fikir.md ]"
check "just spec refuses a name that starts with a dash" "! just spec --help && ! compgen -G 'docs/specs/*-help.md' && says 'does not start with a dash' just spec --help"
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
# A proper noun in quotes passes; a Turkish sentence does not, quoted whole or
# not (spec 022). Asked of the hook's own recipe, one message per file.
cmsg() { printf '%s\n' "$1" > "$tmp/cmsg"; just _commit-msg-check "$tmp/cmsg"; }
check "a quoted name in another language passes the message check" "cmsg \"feat: add the 'Kırmızı Balık' game\" && cmsg 'feat(ui): show \`Kırmızı Balık\` in the title' && cmsg 'feat: add the \"Kırmızı Balık\" game' && cmsg \"fix: don't break 'Kırmızı Balık'\""
check "and a Turkish sentence is still refused, quoted, bare or as the scope" "! cmsg 'fix: oyun açılmıyor' && ! cmsg 'feat(oyun açılmıyor): add x' && ! cmsg \"fix: 'oyun açılmıyor'\" && ! cmsg \"fix: don't çalış\" && ! cmsg \"fix: x'Battı'\" && says \"keeps its letters, in quotes\" cmsg 'fix: oyun açılmıyor' && says 'never for a sentence' cmsg \"fix: 'oyun açılmıyor'\""
check "template-check says up to date"                "says 'up to date' just template-check"
check "doctor finds nothing missing in the repo"      "! says '^  (MISS|warn)' repo_doctor"
check "a new project is not told to map code it has not written yet" "! says 'no code map' repo_doctor"
check "nor about the backbone's comment share, which is the backbone's own" "! says 'of them comments' repo_doctor"
# A settings file Claude Code would skip, and the hooks with it (spec 022): the
# form the 2.1.281 changelog names, and a file that is not JSON. The file is
# put back as it was after each.
cp .claude/settings.json "$tmp/settings-kept"
"$(just _py)" -c "import json,sys; d=json.load(open(sys.argv[1])); d['attribution']=False; json.dump(d,open(sys.argv[1],'w'))" .claude/settings.json
check "doctor says when settings.json holds a bare attribution, which older Claude Code skips whole" "says '^  warn  .claude/settings.json içindeki \"attribution\" ayarı yüzünden eski Claude Code' repo_doctor"
printf '{ "hooks": {}, }\n' > .claude/settings.json
check "and when it is not plain JSON" "says '^  warn  .claude/settings.json bozuk' repo_doctor"
printf '[1, 2]\n' > .claude/settings.json
check "and a JSON that is not an object is not called broken" "says '^  warn  .claude/settings.json JSON ama' repo_doctor && ! says 'settings.json bozuk' repo_doctor"
cp "$tmp/settings-kept" .claude/settings.json
check "and nothing about the file the backbone writes" "! says 'settings.json' repo_doctor"
# A shell startup file a Dart tool wrote into (spec 022): doctor says so, in the
# person's language, and never touches the file. A HOME of its own, so this
# machine's own shell files are never read.
mkdir -p "$tmp/rc-home" "$tmp/rc-en"
printf '# mine\n## [Completion]\n## Completion scripts setup. Remove the following line to uninstall\n[[ -f x ]] && . x || true\n## [/Completion]\n' > "$tmp/rc-home/.zshrc"
rcsum=$(cksum < "$tmp/rc-home/.zshrc")
check "doctor says when ~/.zshrc holds a ## [Completion] block, and leaves the file as it was" "says '^  warn  ~/.zshrc: bir Dart aracı .*## \\[Completion\\] bloğu' env HOME='$tmp/rc-home' just doctor && [ \"\$(cksum < '$tmp/rc-home/.zshrc')\" = '$rcsum' ]"
mv "$tmp/rc-home/.zshrc" "$tmp/rc-home/.bash_profile"
check "and ~/.bash_profile, which bash reads" "says '^  warn  ~/.bash_profile: ' env HOME='$tmp/rc-home' just doctor"
cp "$tmp/rc-home/.bash_profile" "$tmp/rc-home/.zshrc"
check "and both in one line, not the same paragraph twice" "says '^  warn  ~/.zshrc, ~/.bash_profile: ' env HOME='$tmp/rc-home' just doctor && o=\$(env HOME='$tmp/rc-home' just doctor 2>&1) && [ \$(grep -c 'Completion. bloğu' <<<\"\$o\") -eq 1 ]"
rm -f "$tmp/rc-home/.zshrc"
printf '# mine, and a line that only mentions ## [Completion] later on\n' > "$tmp/rc-home/.bash_profile"
check "and says nothing when no such block is there" "! says 'Completion' env HOME='$tmp/rc-home' just doctor"
printf '| chat_lang | en |\n' > "$tmp/rc-en/AGENTS.md"
check "and speaks English in an English project" "says '^~/.zshrc: a Dart tool \\(cli_completion\\) added a ## \\[Completion\\] block' just -f '$root/Justfile' -d '$tmp/rc-en' _doctor-msg completion-block .zshrc"
# spec 013, codemap: what a Flutter project found in its first week, about the code
# map first and the seed files after it. Its runner shims are Swift and Kotlin,
# which is the only reason it was ever told it had code.
mkdir -p src/lib && printf 'class TetrisGame {}\nclass TetrisGameBoard {}\n' > src/lib/game.dart
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
# documents too: most of a project's nodes were .md files (0.9.64). Three runs
# by now, the last two with a map already there.
check "a map that is already there is refreshed from code only, never with update" "[ \$(grep -cx 'extract . --code-only' '$fm/calls') = 3 ] && ! grep -q '^update' '$fm/calls'"
# The map draws no calls in Dart, so an agent asks the words as well. One saved
# file and one brand-new one name the word; the five folders that are not the
# project's code name it too and must stay out. brain/ and .references/ are
# ignored by git as well; the other three would show without the recipe's list.
echo "TetrisGame is the game" >> src/README.md
mkdir -p brain/probe .archive .references/probe graphify-out
for where in brain/probe/n.md .archive/probe.dart .references/probe/r.dart graphify-out/GRAPH_REPORT.md .ai-backbone/probe.txt; do echo "TetrisGame probe" > "$where"; done
check "uses finds a word in saved and in brand-new files, whole words only" "says '^src/README.md:[0-9]+:' just uses TetrisGame && says '^src/lib/game.dart:1:' just uses TetrisGame && ! says 'TetrisGameBoard' just uses TetrisGame && says '^2 line\(s\) in 2 file\(s\)' just uses TetrisGame"
check "uses leaves out the backbone, the vault, the map, references and the archive" "says 'game.dart' just uses TetrisGame && ! says probe just uses TetrisGame"
check "uses answers calmly when no line names the word"  "just uses Zzyzx && says 'No line in this project names \"Zzyzx\"' just uses Zzyzx"
check "uses runs nothing a word asks it to"              "just uses '\$(touch $tmp/PWNED5)' && [ ! -e '$tmp/PWNED5' ]"
# 37 recipes on show is the ceiling, so `uses` took the place of the one nobody
# types: session-start runs the tool-release check once a week, under its
# private name, and it still runs by hand.
check "backbone-news gave up its place on show and still exists" "! says '(^| )backbone-news( |\$)' just --summary && just --show _backbone-news"
check "session-start asks for the tool releases by the name the recipe has" "grep -q 'just _backbone-news' '$root/.ai-backbone/core.just' && ! grep -q 'just backbone-news' '$root/.ai-backbone/core.just'"
# n-fabf4b: 39 commits behind stays quiet. 40 refreshes when graphify is on
# PATH, and names the command when it is not. The project's own Justfile is
# what the inner `just update-map` finds.
mapproj=$tmp/map-stale
rm -rf "$mapproj"
mkdir -p "$mapproj/graphify-out"
git -C "$mapproj" init -qb main
git -C "$mapproj" config user.email "map@example.com"
git -C "$mapproj" config user.name "Map Test"
git -C "$mapproj" config commit.gpgsign false
printf 'x = 0\n' > "$mapproj/src.py"
printf 'map\n' > "$mapproj/graphify-out/GRAPH_REPORT.md"
# just on Windows reads C:/... A Git Bash path makes import? skip the file,
# and _map-if-stale then looks missing (spec 020). The recipe is still there.
printf "import? '%s/.ai-backbone/core.just'\n" "$rootw" > "$mapproj/Justfile"
git -C "$mapproj" add src.py graphify-out/GRAPH_REPORT.md Justfile
git -C "$mapproj" commit -qm "chore: map"
i=1
while [ "$i" -le 39 ]; do
  printf 'x = %s\n' "$i" >> "$mapproj/src.py"
  git -C "$mapproj" add src.py
  git -C "$mapproj" commit -qm "chore: $i"
  i=$((i + 1))
done
: > "$fm/calls"
mapstale() { PATH="$fm:$PATH" just -f "$mapproj/Justfile" -d "$mapproj" "$@"; }
check "a map 39 commits behind HEAD is left alone" \
  "[ -z \"\$(mapstale _map-if-stale)\" ] && [ ! -s \"$fm/calls\" ]"
printf 'x = 40\n' >> "$mapproj/src.py"
git -C "$mapproj" add src.py
git -C "$mapproj" commit -qm "chore: 40"
plain=$tmp/plain-bin
mkdir -p "$plain"
# Git Bash `ln -s` of just.exe as the name `just` is not runnable (no PATHEXT
# match). A wrapper keeps the real binary and hides graphify (spec 020).
printf '#!/bin/sh\nexec "%s" "$@"\n' "$(command -v just)" > "$plain/just"
printf '#!/bin/sh\nexec "%s" "$@"\n' "$(command -v git)" > "$plain/git"
chmod +x "$plain/just" "$plain/git"
mapplain() { PATH="$plain:/usr/bin:/bin" just -f "$mapproj/Justfile" -d "$mapproj" "$@"; }
check "without graphify a map 40 commits behind names update-map" \
  "says 'Code map: 40 commits behind HEAD -> just update-map' mapplain _map-if-stale && [ ! -s \"$fm/calls\" ]"
check "a map 40 commits behind HEAD is refreshed when graphify is on PATH" \
  "says 'Code map: refreshed, it was 40 commits behind HEAD' mapstale _map-if-stale && grep -qx 'extract . --code-only' \"$fm/calls\""
check "session-start says that the stale map was refreshed" \
  "says 'Code map: refreshed, it was 40 commits behind HEAD' mapstale session-start"
rm -rf src/lib brain/probe .archive .references graphify-out .graphifyignore .ai-backbone/probe.txt "$fm"
git checkout -q -- src/README.md
# The seed files. Key and certificate files are secrets and live in brain/secrets/.
# save stages every file git does not ignore, so the ignore list is the only thing
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
check "just audit-lenses writes the design lens beside the five" "rm -f docs/audit-lenses.md && says 'design beside them' just audit-lenses && grep -q '### Design' docs/audit-lenses.md && grep -F -q '.agents/skills/design/SKILL.md' docs/audit-lenses.md && grep -F -q 'Rust review checklist' .agents/skills/audit/SKILL.md && rm -f docs/audit-lenses.md"
check "the audit skill gives every finding a verdict, anchors severity, and keeps a flag apart" "grep -q '^## Verdicts' .agents/skills/audit/SKILL.md && grep -q 'Needs validation' .agents/skills/audit/SKILL.md && grep -q 'The severity never exceeds the impact shown' .agents/skills/audit/SKILL.md && grep -q '^## A flag is not a finding' .agents/skills/audit/SKILL.md && grep -q 'security-audit-skill/blob/c1c8a8c/' .agents/skills/audit/SKILL.md"
check "the audit skill's Rust lens names the production hazards" "grep -q '^## A Rust lens' .agents/skills/audit/SKILL.md && grep -q '\`unsafe\` without a \`SAFETY\` comment' .agents/skills/audit/SKILL.md && grep -q 'canonicalize' .agents/skills/audit/SKILL.md && grep -q 'size or depth' .agents/skills/audit/SKILL.md"
check "the delegate skill says a pin bump is fetched by the desk, and names the ref guard" "grep -q 'The worker has no network' .agents/skills/delegate/SKILL.md && grep -q 'release notes into \`target/\`' .agents/skills/delegate/SKILL.md && grep -q 'first parent is the old tip' .agents/skills/delegate/SKILL.md && grep -q 'zero-width character' .agents/skills/delegate/SKILL.md"
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
mkdir -p "$tmp/bb/.ai-backbone" "$tmp/bb/.agents/skills/session" && cp "$root/.ai-backbone/manifest.txt" "$tmp/bb/.ai-backbone/" && printf '# core.just, version 1.0.0\nsave message="":\n    @true\n' > "$tmp/bb/.ai-backbone/core.just" && : > "$tmp/bb/.agents/skills/session/SKILL.md"
( cd "$tmp/bb" && git init -qb main && git add -A && git commit -qm "chore: stand-in backbone" ) >/dev/null 2>&1
# The line carries an id, never the project's name (spec 024); the pairing is
# the project's own, in brain/, and session-start reads the state from it.
check "backbone-note lands in the backbone's backlog with a date and an id, never the project's name" "AI_BACKBONE='$tmp/bb' just backbone-note 'core.just: save says the wrong thing' && grep -qE '^- \[ \] $(date +%Y-%m-%d), n-[0-9a-f]{6}: core.just: save says the wrong thing\$' '$tmp/bb/docs/backlog.md' && ! grep -q 'Deneme' '$tmp/bb/docs/backlog.md'"
check "and keeps the pairing in this project's brain/, where session-start reads which are open" "id=\$(grep -oE 'n-[0-9a-f]{6}' '$tmp/bb/docs/backlog.md' | tail -1) && grep -q \"^- \$id $(date +%Y-%m-%d): core.just: save says the wrong thing\" brain/notes-to-backbone.md && says 'NOTES TO THE BACKBONE \(1 still open, 0 on their way, 0 set aside by its hooks, 0 no longer listed' env AI_BACKBONE='$tmp/bb' just session-start && says 'save says the wrong thing' env AI_BACKBONE='$tmp/bb' just session-start"
perl -ni -e 'print unless /save says the wrong thing/' "$tmp/bb/docs/backlog.md"
check "a line gone from the backlog is no longer listed: built" "says 'NOTES TO THE BACKBONE \(0 still open, 0 on their way, 0 set aside by its hooks, 1 no longer listed' env AI_BACKBONE='$tmp/bb' just session-start"
printf -- '- [x] 2026-01-01, n-cccccc: core.just: built (49e35f4)\n' >> "$tmp/bb/docs/backlog.md"
printf -- '- n-cccccc 2026-01-01: core.just: built\n' >> brain/notes-to-backbone.md
check "a ticked backlog line is built, not still open" "says 'NOTES TO THE BACKBONE \(0 still open, 0 on their way, 0 set aside by its hooks, 2 no longer listed' env AI_BACKBONE='$tmp/bb' just session-start && ! says 'core.just: built' env AI_BACKBONE='$tmp/bb' just session-start"
perl -ni -e 'print unless /n-cccccc/' "$tmp/bb/docs/backlog.md" brain/notes-to-backbone.md
printf -- '- [ ] 2026-01-01, n-aaaaaa: core.just: kept in the outbox\n' > "$tmp/bb/.git/ai-backbone-notes-outbox"; printf -- '- [ ] 2026-01-01, n-bbbbbb: core.just: set aside\n' > "$tmp/bb/.git/ai-backbone-notes-refused"
printf -- '- n-aaaaaa 2026-01-01: core.just: kept in the outbox\n- n-bbbbbb 2026-01-01: core.just: set aside\n' >> brain/notes-to-backbone.md
check "a note still in the outbox is on its way, and one the hooks set aside is said so" "says '\(0 still open, 1 on their way, 1 set aside by its hooks, 1 no longer listed' env AI_BACKBONE='$tmp/bb' just session-start"
rm -f "$tmp/bb/.git/ai-backbone-notes-outbox" "$tmp/bb/.git/ai-backbone-notes-refused"
check "a note that names this project, or one next to the backbone, is refused, and one that names no recipe, file or skill too" "! AI_BACKBONE='$tmp/bb' just backbone-note 'core.just: Deneme Projesi wants' && says 'the name of this project \(Deneme Projesi\)' env AI_BACKBONE='$tmp/bb' just backbone-note 'core.just: deneme projesi wants' && ! AI_BACKBONE='$tmp/bb' just backbone-note 'something vague' && says 'carries no recipe \(just <name>\), file or skill' env AI_BACKBONE='$tmp/bb' just backbone-note 'something vague' && AI_BACKBONE='$tmp/bb' just backbone-note 'the session skill should say it' && [ \$(grep -c '^- \[ \]' '$tmp/bb/docs/backlog.md') -eq 1 ]"
# A refused note leaves no pairing; a decision names the line's id and needs
# no other anchor; a folder on a tracked path is one; the help text's own
# example passes.
lines=$(grep -c '^- n-' brain/notes-to-backbone.md)
check "a refused note is nowhere: no pairing either" "! AI_BACKBONE='$tmp/bb' just backbone-note 'something vague' && [ \$(grep -c '^- n-' brain/notes-to-backbone.md) -eq $lines ]"
check "a decision that names the line's id, a note naming a folder on a tracked path, and the help text's example all pass" "AI_BACKBONE='$tmp/bb' just backbone-note 'decision: n-9b243a yes, the way you would' && AI_BACKBONE='$tmp/bb' just backbone-note 'graphify 9.9 is out: renames cluster-only -> .ai-backbone and docs; blocked: needs an attended session' && AI_BACKBONE='$tmp/bb' just backbone-note 'just save prints the wrong thing when ...' && [ \$(grep -c '^- \[ \]' '$tmp/bb/docs/backlog.md') -eq 4 ]"
# The names next to the backbone: a folder with a space, an AGENTS.md row
# with Turkish letters, matched in any case; the backbone's own name never.
mkdir -p "$tmp/bb-side/Sibling App/.ai-backbone" "$tmp/bb-side/old-adopt/.ai-backbone" && : > "$tmp/bb-side/Sibling App/.ai-backbone/core.just" && : > "$tmp/bb-side/old-adopt/.ai-backbone/core.just" && printf '| project | Güneş Işığı |\n' > "$tmp/bb-side/Sibling App/AGENTS.md" && printf '| project | ai-backbone |\n' > "$tmp/bb-side/old-adopt/AGENTS.md"
mv "$tmp/bb" "$tmp/bb-side/ai-backbone"
check "a project next to the backbone is known by its folder and its AGENTS.md name, read from the machine, in any case of letters; the backbone's own name never" "[ \"\$(just _sibling-names '$tmp/bb-side/ai-backbone' | tr '\n' '|')\" = 'Güneş Işığı|Sibling App|old-adopt|' ] && says 'the name of a project on this machine \(Güneş Işığı\)' env AI_BACKBONE='$tmp/bb-side/ai-backbone' just backbone-note 'core.just: GÜNEŞ IŞIĞI wants' && says 'the name of a project on this machine \(Sibling App\)' env AI_BACKBONE='$tmp/bb-side/ai-backbone' just backbone-note 'core.just: like sibling app' && env AI_BACKBONE='$tmp/bb-side/ai-backbone' just backbone-note 'the .ai-backbone/core.just of ai-backbone should x'"
# The backbone's own hook: a commit in it that names a neighbour is refused;
# the names come from the machine, and a project's commits are never read.
printf '# ai-backbone\n' > "$tmp/bb-side/ai-backbone/README.md"; echo 'the sibling app does x, and güneş ışığı' > "$tmp/bb-side/ai-backbone/docs/notes.md"; git -C "$tmp/bb-side/ai-backbone" add -A
inhook() { env JUST_JUSTFILE="$root/Justfile" JUST_WORKING_DIRECTORY="$tmp/bb-side/ai-backbone" just _no-project-names "$@"; }
check "the backbone's hook refuses a commit that names a project next to it, and says which" "! inhook && says 'names a project next to it: Güneş Işığı \(1 line\(s\)\), Sibling App \(1 line' inhook"
echo 'a project does x' > "$tmp/bb-side/ai-backbone/docs/notes.md"; git -C "$tmp/bb-side/ai-backbone" add -A
check "and lets one through that says 'a project'"        "inhook"
echo 'a respelling: SiblingApp, sibling_app and güneş_ışığı' > "$tmp/bb-side/ai-backbone/docs/notes.md"; git -C "$tmp/bb-side/ai-backbone" add -A
check "a respelling that keeps the letters is the name too" "! inhook && says 'Güneş Işığı \(1 line\(s\)\), Sibling App \(1 line' inhook"
echo 'clean' > "$tmp/bb-side/ai-backbone/docs/notes.md"; echo clean > "$tmp/bb-side/ai-backbone/docs/sibling-app-notes.md"; git -C "$tmp/bb-side/ai-backbone" add -A
check "a file named after a neighbour is refused too"   "! inhook && says 'Sibling App \(1 line' inhook"
rm -f "$tmp/bb-side/ai-backbone/docs/sibling-app-notes.md"; git -C "$tmp/bb-side/ai-backbone" add -A
printf 'fix: what Sibling App hit\n' > "$tmp/bb-side/msg"
check "and so is a commit message that names one, through the same recipe"  "! inhook '$tmp/bb-side/msg' && says 'this message names a project next to it: Sibling App' inhook '$tmp/bb-side/msg' && grep -q 'stages: \[commit-msg\]' '$root/.pre-commit-config.yaml' && [ \$(grep -c 'entry: just _no-project-names' '$root/.pre-commit-config.yaml') -eq 2 ]"
mkdir -p "$tmp/bb-side/acme/.ai-backbone" && : > "$tmp/bb-side/acme/.ai-backbone/core.just" && printf '| project | Acme Tech |\n' > "$tmp/bb-side/acme/AGENTS.md"
echo 'the backbone lives at https://github.com/acmetech/ai-backbone and https://GitHub.com/AcmeTech/ai-backbone.git' > "$tmp/bb-side/ai-backbone/docs/notes.md"; git -C "$tmp/bb-side/ai-backbone" add -A
check "the backbone's own GitHub address is not a name, whoever owns it" "inhook && [ -z \"\$(just _note-check 'core.just: see github.com/acmetech/ai-backbone' '$tmp/bb-side/ai-backbone' '')\" ]"
echo 'the backbone lives at https://github.com/acmetech/ai-backbone, made by acme tech' > "$tmp/bb-side/ai-backbone/docs/notes.md"; git -C "$tmp/bb-side/ai-backbone" add -A
check "while the same name elsewhere in the line is"    "! inhook && says 'Acme Tech \(1 line' inhook && says 'the name of a project on this machine \(Acme Tech\)' just _note-check 'core.just: acmetech wants' '$tmp/bb-side/ai-backbone' ''"
rm -r "$tmp/bb-side/acme"
mkdir -p "$tmp/bb-side/ai-backbone/brain"; printf '# kept out\nSecret Product\n' > "$tmp/bb-side/ai-backbone/brain/private-names.txt"
check "a private list in the clone's brain/ names what to keep out as well" "says 'Secret Product' just _sibling-names '$tmp/bb-side/ai-backbone' && echo 'the secret product ships' > '$tmp/bb-side/ai-backbone/docs/notes.md' && git -C '$tmp/bb-side/ai-backbone' add -A && ! inhook"
rm -r "$tmp/bb-side/ai-backbone/brain"
check "in a project the hook reads nothing"              "just _no-project-names"
check "and the backbone's own checks run it on every commit" "grep -q 'entry: just _no-project-names' '$root/.pre-commit-config.yaml'"
mv "$tmp/bb-side/ai-backbone" "$tmp/bb"; rm -f "$tmp/bb/docs/notes.md"; git -C "$tmp/bb" reset -q --hard >/dev/null 2>&1
rm -f brain/notes-to-backbone.md
check "backbone-note saves the note in the backbone by itself"  "says '^docs: backlog note$' git -C '$tmp/bb' log -1 --format=%s && [ -z \"\$(git -C '$tmp/bb' status --short)\" ]"
check "backbone-note runs nothing a note asks it to"   "AI_BACKBONE='$tmp/bb' just backbone-note 'core.just: \$(touch $tmp/PWNED2)' && [ ! -e '$tmp/PWNED2' ] && grep -qF 'core.just: \$(touch $tmp/PWNED2)' '$tmp/bb/docs/backlog.md'"
check "backbone-note with no backbone nearby writes nothing"  "! AI_BACKBONE='$tmp/none' just backbone-note 'core.just: x' && [ ! -d '$tmp/none' ]"
# spec 013, save-ci-update: what save, ci, publish and template-update learned
# while the backlog was cleared. The checks have a project of their own, so that
# nothing planted here reaches the checks around them.
fi
if lane_wants save; then
section "save, ci and template-update (spec 013)"
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
fi
if lane_wants clone; then
section "the backbone's clone keeps itself level"
hub="$tmp/level"; mkdir -p "$hub/seed/docs" "$hub/seed/.ai-backbone"
( cd "$hub" && git init -q --bare -b main remote.git && cd seed && git init -qb main \
  && cp "$root/.ai-backbone/manifest.txt" .ai-backbone/ && cp "$root/.gitattributes" . \
  && printf '# ai-backbone\n' > README.md && printf '# core.just, version 1.0.0\n' > .ai-backbone/core.just \
  && printf '# Backlog\n\n- [ ] 2026-01-01, a: first\n- [ ] 2026-01-02, b: second\n' > docs/backlog.md \
  && git add -A && git commit -qm "chore: seed" && git remote add origin ../remote.git && git push -q origin main main:cloud \
  && cd .. && git clone -q remote.git bb && git clone -q remote.git agent ) >/dev/null 2>&1
# The clone has hooks, as one that ran just hooks-install has: a note's commit
# runs them, and a clone without them sends nothing (spec 023).
hookok() { printf '#!/bin/sh\nexit 0\n' > "$hub/bb/.git/hooks/pre-commit"; chmod +x "$hub/bb/.git/hooks/pre-commit"; }
hookok
# The scheduled agent works on cloud and the gate carries cloud to main, forward
# only: `moved` does both. `onmain` is a push to main alone, what a note was
# until 3.30.0.
promoted() { git -C "$hub/remote.git" merge-base --is-ancestor main cloud && git -C "$hub/remote.git" update-ref refs/heads/main "$(git -C "$hub/remote.git" rev-parse cloud)"; }
moved()  { ( cd "$hub/agent" && git fetch -q origin && git checkout -q -B cloud origin/cloud && eval "$1" && git add -A && git commit -qm "fix: the scheduled agent" && git push -q origin HEAD:cloud ) >/dev/null 2>&1 && promoted; }
onmain() { ( cd "$hub/agent" && git fetch -q origin && git checkout -q -B main origin/main && eval "$1" && git add -A && git commit -qm "docs: backlog note" && git push -q origin HEAD:main ) >/dev/null 2>&1; }
onhub()  { git -C "$hub/remote.git" show "cloud:${1:-docs/backlog.md}"; }
onmainhub() { git -C "$hub/remote.git" show "main:${1:-docs/backlog.md}"; }
online() { env -u AI_BACKBONE_OFFLINE AI_BACKBONE="$hub/bb" "$@"; }
level()  { git -C "$hub/bb" fetch -q origin main && [ "$(git -C "$hub/bb" rev-list --count HEAD...origin/main)" = 0 ] && [ -z "$(git -C "$hub/bb" status --short)" ]; }
rewind() { git -C "$hub/bb" reset -q --hard origin/main; }
hublines() { onhub > "$tmp/hub.md"; grep -c '^- \[' "$tmp/hub.md"; }
box="$hub/bb/.git/ai-backbone-notes-outbox"
# The backlog itself passes the rule a note is held to, and the pages say the route.
bad=""; while IFS= read -r nl; do nr=$(just -f "$root/Justfile" -d "$root" _note-check "$nl" "$root"); [ -z "$nr" ] || bad="$bad$nr: ${nl:0:70}"$'\n'; done < <(grep '^- \[' "$root/docs/backlog.md")
check "no line of the backbone's own backlog carries what a note may not" "[ -z \"\$bad\" ] || { printf '%s\n' \"\$bad\"; false; }"
# Open lines, or a built line ticked with its commit, each with a date and an
# id in the project's place (spec 024). (uncommitted) is that tick while the
# index lock is refused; the next save replaces the word with the hash.
# No tracked file names a project next to this backbone on this machine
# (nothing next to it on a runner: the check bites on the maintainer's machine).
check "the backlog holds open lines, or a built line ticked with its commit, each dated and with an id, or a question for the maintainer" "! grep -vE '^- \[x\] [0-9]{4}-[0-9]{2}-[0-9]{2}, n-[0-9a-f]{6}: (.*[0-9a-f]{7}|.*\\(uncommitted\\))|^- \\[[ ?]\\] [0-9]{4}-[0-9]{2}-[0-9]{2}, n-[0-9a-f]{6}: |^[^ -]|^\$' '$root/docs/backlog.md'"
sib=$(just _sibling-names "$root" | tr '\n' '|')
# The gate's author is the maker (2026-11-11), taken out before the scan the
# way _no-project-names takes out the backbone's GitHub address. A name that
# remains is still a hit.
hits=""; if [ -n "$sib" ]; then hits=$(cd "$root" && IFS='|'; for n in $sib; do [ -n "$n" ] || continue; git grep -ilF -w -- "$n" -- . ':!LICENSE' ':!brain' 2>/dev/null | while IFS= read -r f; do [ -n "$f" ] || continue; perl -CSA -e 'my ($name, $path) = @ARGV; open my $fh, "<", $path or exit 0; local $/; my $t = <$fh>; my $q = quotemeta($name); exit($t =~ /(?<![A-Za-z0-9_])$q(?![A-Za-z0-9_])/i ? 1 : 0);' -- "$n" "$f" || printf "%s: %s\n" "$n" "$f"; done; done); fi
check "no tracked file names a project next to this backbone (LICENSE aside)" "[ -z \"\$hits\" ] || { printf '%s\n' \"\$hits\"; false; }"
check "the skill, the getting-started page and how-it-works say the route" "grep -q 'on GitHub.s .cloud.' '$root/.agents/skills/backbone-dev/SKILL.md' && grep -q 'The backlog is public' '$root/docs/01-getting-started.md' && grep -q 'the branch .cloud. on GitHub' '$root/docs/how-it-works.md'"
check "and the brief, the three skills, the pages and the backlog's header say the backbone knows no project" "for pg in .ai-backbone/routine.md .agents/skills/backbone-dev/SKILL.md .agents/skills/session/SKILL.md docs/01-getting-started.md docs/how-it-works.md docs/backlog.md; do grep -q 'knows no project' \"$root/\$pg\" || { echo \"\$pg\"; false; }; done"
# A note is a commit on cloud, made from a side worktree (spec 023): the clone's
# own files, branch and history stay as they were, and main is the gate's.
moved "printf -- '- [ ] 2026-01-03, agent: third\n' >> docs/backlog.md"
was=$(git -C "$hub/bb" rev-parse HEAD)
check "a note goes to GitHub's cloud on top of what is there, never to main, and the clone's own files are left alone" "says '^  sent +1 note' online just backbone-note 'core.just: to cloud' && says 'to cloud' onhub && says 'agent: third' onhub && ! says 'to cloud' onmainhub && ! grep -q 'to cloud' '$hub/bb/docs/backlog.md' && [ \$(git -C '$hub/bb' rev-parse HEAD) = $was ] && [ -z \"\$(git -C '$hub/bb' status --short)\" ] && [ -z \"\$(git -C '$hub/bb' worktree list | sed 1d)\" ]"
check "and every note is told first, once, that the backlog is public" "o=\$(online just backbone-note 'core.just: told so' 2>&1); first=\$(sed -n 1p <<<\"\$o\"); [[ \"\$first\" == '  public  docs/backlog.md is on GitHub for anyone to read, and the line carries no project'* ]] && [ \$(grep -c '^  public ' <<<\"\$o\") -eq 1 ]"
# What is refused: a file under a project's numbered brain/ folders, an e-mail,
# a home folder, however they are spelled. The folder names, a pin with an @,
# a sandbox path and a git address are the backbone's own words and pass.
lines=$(hublines)
check "a note that points into a project's brain/ is refused, names project-note, and writes nothing anywhere" "! online just backbone-note 'core.just: plan in brain/02-research/2026-09-29-plan.md' && says 'carries a path into a project.s brain/' online just backbone-note 'core.just: plan in brain\\02-research\\x.md' && says 'just project-note <project>' online just backbone-note 'core.just: plan in brain/01-journal/x.md' && ! says 'public' online just backbone-note 'core.just: plan in brain/01-journal/x.md' && [ ! -e '$box' ] && [ \$(hublines) -eq $lines ]"
check "and so is one with an e-mail address or a home folder in it" "says 'carries an e-mail address' online just backbone-note 'core.just: ask ali@example.com' && says 'carries an e-mail address' online just backbone-note 'core.just: ask alı@örnek.com' && says 'carries a home folder' online just backbone-note 'core.just: see /Users/ali/work/x' && says 'carries a home folder' online just backbone-note 'core.just: log in \`/Users/ali/x\`' && says 'carries a home folder' online just backbone-note 'core.just: in C:/Users/ali/x' && [ ! -e '$box' ] && [ \$(hublines) -eq $lines ]"
check "while brain/ and its folder names, a pin with an @, a sandbox path and a git address pass" "says '^  sent +1 note' online just backbone-note 'core.just: session-end copies brain/ and brain/05-files twice; bump actions/checkout@v7.1.0 and uv@0.12.19; the sandbox at /home/user/ai-backbone and CI at /home/runner/work; ref-add takes git@github.com:x/y.git'"
# GitHub away: the note waits on this machine and goes out with the next one,
# on top of what cloud got meanwhile, or with the next project session.
git -C "$hub/bb" remote set-url origin "$hub/nowhere.git"
check "a note that cannot reach GitHub is kept on this machine, and says so" "says 'not sent: GitHub not reachable' online just backbone-note 'core.just: while GitHub was away' && grep -q 'while GitHub was away' '$box' && ! says '^  sent ' online just backbone-note 'core.just: still away'"
git -C "$hub/bb" remote set-url origin "$hub/remote.git"
moved "printf -- '- [ ] 2026-01-04, agent: fourth\n' >> docs/backlog.md"
check "the kept notes go out with the next one, on top of what is new there" "says '^  sent +3 note' online just backbone-note 'core.just: back again' && says 'while GitHub was away' onhub && says 'still away' onhub && says 'back again' onhub && says 'agent: fourth' onhub && [ ! -e '$box' ]"
git -C "$hub/bb" remote set-url origin "$hub/nowhere.git"
online just backbone-note 'core.just: kept for the session' >/dev/null 2>&1
git -C "$hub/bb" remote set-url origin "$hub/remote.git"
check "or with the next project session, which says so" "says '^Backbone: sent +1 note' online just _backbone-refresh '$hub/bb' && says 'kept for the session' onhub && [ ! -e '$box' ] && level"
# The clone's own state keeps no note from going out: unsaved work, a rebase
# left half done, a branch of its own (below), no branch at all (below), and a
# note written inside the backbone on main go the same way.
echo dirty >> "$hub/bb/README.md"; mkdir "$hub/bb/.git/rebase-merge"
check "a note goes out from a clone with unsaved work and a half-done rebase, and both are left as they were" "says '^  sent +1 note' online just backbone-note 'core.just: from a dirty clone' && says 'from a dirty clone' onhub && [ -d '$hub/bb/.git/rebase-merge' ] && [ \"\$(git -C '$hub/bb' status --short)\" = ' M README.md' ]"
git -C "$hub/bb" remote set-url origin "$hub/nowhere.git"
online just backbone-note 'core.just: kept while dirty' >/dev/null 2>&1
git -C "$hub/bb" remote set-url origin "$hub/remote.git"
check "and a project's session sends the kept notes before it says the clone is not level" "says '^Backbone: sent +1 note' online just _backbone-refresh '$hub/bb' && says 'kept while dirty' onhub && says 'half done' online just _backbone-refresh '$hub/bb'"
rmdir "$hub/bb/.git/rebase-merge"; git -C "$hub/bb" checkout -q -- README.md
( cd "$hub/bb" && printf -- '- [ ] 2020-01-01, old: a note commit from before 3.30.0\n' >> docs/backlog.md && git commit -qam "docs: backlog note" ) >/dev/null 2>&1
check "a note commit an older backbone left on main is lifted into the box, sent to cloud, and main here is level again" "says 'lifted into the outbox' online just _backbone-level '$hub/bb' GitHub && says 'before 3.30.0' onhub && ! says 'before 3.30.0' onmainhub && level"
rewind
inbbnote() { env -u AI_BACKBONE_OFFLINE -u AI_BACKBONE JUST_JUSTFILE="$root/Justfile" JUST_WORKING_DIRECTORY="$hub/bb" just backbone-note "$@"; }
was=$(git -C "$hub/bb" rev-parse HEAD)
check "a note written inside the backbone on main goes to cloud the same way, and main stays where it was" "says '^  sent +1 note' inbbnote 'core.just: from inside on main' && says 'from inside on main' onhub && ! says 'from inside on main' onmainhub && [ \$(git -C '$hub/bb' rev-parse HEAD) = $was ] && ! grep -q 'from inside on main' '$hub/bb/docs/backlog.md'"
( cd "$hub/bb" && printf '# ai-backbone, edited here\n' > README.md && git commit -qam "docs: saved here" ) >/dev/null 2>&1
moved "printf '# ai-backbone, edited there\n' > README.md"
check "work that does not fit is said, never 'up to date', and no rebase is left behind" "says 'do not fit together' online just _backbone-level '$hub/bb' GitHub && ! says 'up to date' online just _backbone-level '$hub/bb' GitHub && [ ! -d '$hub/bb/.git/rebase-merge' ] && [ ! -d '$hub/bb/.git/rebase-apply' ] && [ -z \"\$(git -C '$hub/bb' status --short)\" ]"
was=$(git -C "$hub/bb" rev-parse HEAD)
check "a project's session never rebases saved work from outside, and says what it is compared with may be old" "says 'Backbone: .*saved but unpublished.*may be old' online just _backbone-refresh '$hub/bb' && [ \$(git -C '$hub/bb' rev-parse HEAD) = $was ]"
rewind
( cd "$hub/bb" && echo x >> README.md && git commit -qam "docs: saved, not published" ) >/dev/null 2>&1
check "saved work nobody published is said, and not pushed for them" "says 'not on GitHub yet -> just publish' online just _backbone-level '$hub/bb' GitHub && ! says 'saved, not published' git -C '$hub/remote.git' log --format=%s main"
rewind
# The hooks run on the note's commit as on any other (gitleaks among them): a
# clone without them sends nothing, a refused note is kept with what the hooks
# said, never called sent, and goes out once they pass.
# Taken away, not made unrunnable: on Windows the x bit is the shebang, and
# chmod -x changes nothing there (measured on the gate, 2026-09-29).
rm -f "$hub/bb/.git/hooks/pre-commit"
check "a clone with no hooks sends nothing and names hooks-install: nothing there would catch a secret" "says 'no git hooks' online just backbone-note 'core.just: from a clone without hooks' && says 'just hooks-install' online just backbone-note 'core.just: and again' && ! says 'from a clone without hooks' onhub && grep -q 'and again' '$box'"
hookok
check "and the kept notes go out once the hooks are there" "says '^  sent +3 note' online just backbone-note 'core.just: hooks again' && says 'from a clone without hooks' onhub"
printf '#!/bin/sh\necho "a check said no"\nexit 1\n' > "$hub/bb/.git/hooks/pre-commit" && chmod +x "$hub/bb/.git/hooks/pre-commit"
refusedf="$hub/bb/.git/ai-backbone-notes-refused"
check "a note the backbone's own checks refuse is set aside with what they said, never called sent, and blocks nothing" "says 'not sent: the backbone.s own checks refused every note' online just backbone-note 'core.just: refused' && says 'a check said no' online just backbone-note 'core.just: refused again' && ! says '^  sent ' online just backbone-note 'core.just: refused twice' && ! says 'refused' onhub && [ \$(grep -c 'refused' '$refusedf') -eq 3 ] && [ ! -e '$box' ] && [ -s '$refusedf.log' ] && [ -z \"\$(git -C '$hub/bb' worktree list | sed 1d)\" ]"
hookok
check "once they pass, the new note goes and the set-aside lines stay aside" "says '^  sent +1 note' online just backbone-note 'core.just: checks pass again' && says 'checks pass again' onhub && ! says 'refused twice' onhub && grep -q 'refused twice' '$refusedf'"
# A hook that refuses one line (a secret) and not the others: the batch is
# sent line by line, and only that line is set aside.
printf '#!/bin/sh\ngit diff --cached --quiet -G secret && exit 0\necho "a secret in a note"\nexit 1\n' > "$hub/bb/.git/hooks/pre-commit"
git -C "$hub/bb" remote set-url origin "$hub/nowhere.git"
online just backbone-note 'core.just: a harmless line first' >/dev/null 2>&1; online just backbone-note 'core.just: a secret token in the middle' >/dev/null 2>&1
git -C "$hub/bb" remote set-url origin "$hub/remote.git"
check "a hook that refuses one line sets that line aside and the others go" "o=\$(online just backbone-note 'core.just: a harmless line last' 2>&1); grep -q '^  sent    2 note' <<<\"\$o\" && grep -q '1 refused by the checks and set aside' <<<\"\$o\" && says 'a harmless line first' onhub && says 'a harmless line last' onhub && ! says 'secret token' onhub && grep -q 'a secret token in the middle' '$refusedf' && grep -q 'a secret in a note' '$refusedf.log' && [ ! -e '$box' ]"
hookok
# The box is a file other projects append to while a send runs: the batch is
# moved out first, so the box is never deleted under a new line; a batch a
# killed run left returns to the box after ten minutes; a half line is closed
# before the next; a line cloud already has (a push that landed while its
# answer was lost) is not sent twice; a backbone that is a linked worktree
# sends the same way; a GitHub with no cloud branch keeps the note.
printf -- '- [ ] 2026-01-05, p: half a line left behind' > "$box"
printf -- '- [ ] 2026-01-05, p: from a run that died\n' > "$box.sending.4242"; touch -t 202001010000 "$box.sending.4242"
printf '#!/bin/sh\nprintf -- "- [ ] 2026-01-05, q: appended while a send ran\\n" >> "%s"\nexit 0\n' "$box" > "$hub/bb/.git/hooks/pre-commit"
check "a half line is closed, a dead run's batch returns, and a line appended mid-send is kept for the next one" "o=\$(online just backbone-note 'core.just: the next note' 2>&1); grep -q '^  sent    3 note' <<<\"\$o\" && says '^- \[ \] 2026-01-05, p: half a line left behind\$' onhub && says 'from a run that died' onhub && says 'the next note' onhub && ! says 'appended while a send ran' onhub && grep -q 'appended while a send ran' '$box' && [ ! -e '$box.sending.4242' ]"
hookok
check "and it goes out with the one after"              "says '^  sent +2 note' online just backbone-note 'core.just: the one after' && says 'appended while a send ran' onhub"
printf '#!/bin/sh\nif [ ! -e "%s" ]; then touch "%s"; git push -q origin HEAD:refs/heads/cloud; exit 1; fi\nexit 0\n' "$hub/pushed-once" "$hub/pushed-once" > "$hub/bb/.git/hooks/pre-push"; chmod +x "$hub/bb/.git/hooks/pre-push"
lines=$(hublines)
check "a push that landed while its answer was lost is not sent twice" "says 'there already' online just backbone-note 'core.just: answer lost' && [ \$(hublines) -eq $((lines+1)) ] && [ ! -e '$box' ]"
rm -f "$hub/bb/.git/hooks/pre-push" "$hub/pushed-once"
git -C "$hub/bb" worktree add -q "$hub/bb-wt" -b wt origin/main >/dev/null 2>&1
check "a backbone that is a linked worktree (.git a file) sends the same way, and nothing is written into it" "says '^  sent +1 note' env -u AI_BACKBONE_OFFLINE AI_BACKBONE='$hub/bb-wt' just backbone-note 'core.just: from a linked worktree' && says 'from a linked worktree' onhub && [ -z \"\$(git -C '$hub/bb-wt' status --short)\" ]"
git -C "$hub/bb" worktree remove --force "$hub/bb-wt" >/dev/null 2>&1; git -C "$hub/bb" branch -q -D wt >/dev/null 2>&1
( cd "$hub" && git init -q --bare -b main hub9.git && git -C agent push -q "$hub/hub9.git" origin/main:refs/heads/main ) >/dev/null 2>&1
git -C "$hub/bb" remote set-url origin "$hub/hub9.git"
check "a GitHub with no cloud branch keeps the note and says until when" "says 'no cloud branch' online just backbone-note 'core.just: no cloud there' && says 'until it has one' online just _backbone-refresh '$hub/bb' && grep -q 'no cloud there' '$box'"
git -C "$hub/bb" remote set-url origin "$hub/remote.git"
online just backbone-note 'core.just: cloud is back' >/dev/null 2>&1
git -C "$hub/bb" checkout -q -b side
was=$(git -C "$hub/bb" rev-parse HEAD)
check "a clone on another branch is named by the session, and a note still goes out from it, touching nothing there" "says \"not brought up to date: .* is on 'side'\" online just _backbone-refresh '$hub/bb' && says '^  sent +1 note' online just backbone-note 'core.just: from a side branch' && says 'from a side branch' onhub && [ \$(git -C '$hub/bb' rev-parse HEAD) = $was ] && [ \"\$(git -C '$hub/bb' symbolic-ref --short HEAD)\" = side ]"
git -C "$hub/bb" checkout -q main; git -C "$hub/bb" branch -q -D side
lines=$(hublines)
online just backbone-note "$(printf 'core.just: first half\n- [ ] 2020-01-01, x: a forged line\tand a tab')" >/dev/null 2>&1   # "agent" is a folder next to bb here, and a name next to the backbone is refused
check "a note with a newline in it writes one line"    "[ \$(hublines) -eq $((lines+1)) ] && says 'core.just: first half - \[ \] 2020-01-01, x: a forged line and a tab\$' onhub"
# A note sends itself, never the saved work under it; and a tag is what GitHub's
# main says, never what this folder's files say (both measured the other way).
( cd "$hub/bb" && echo y >> README.md && git commit -qam "feat: half done, saved, not published" ) >/dev/null 2>&1
check "a note never publishes the saved work that sits under it" "says '^  sent +1 note' online just backbone-note 'core.just: over unpublished work' && says 'over unpublished work' onhub && ! says 'half done' git -C '$hub/remote.git' log --format=%s cloud && ! says 'half done' git -C '$hub/remote.git' log --format=%s main"
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
check "a lock left by a run that died is cleared"      "says 'pulled [1-9][0-9]* new commit' online just _backbone-refresh '$hub/bb' && [ ! -d '$hub/bb/.git/backbone-level.lock' ]"
# A scheduled run's checkout has no branch and is exactly what GitHub has.
git clone -q "$hub/remote.git" "$hub/cloud" >/dev/null 2>&1 && git -C "$hub/cloud" checkout -q --detach origin/main
check "a checkout with no branch that is what GitHub has is called up to date" "says 'GitHub: up to date \(a checkout with no branch' online just _backbone-level '$hub/cloud' GitHub"
git -C "$hub/bb" checkout -q --detach
check "from a clone on no branch a note still goes out, and nothing is written into the clone" "says '^  sent +1 note' online just backbone-note 'core.just: onto no branch' && says 'onto no branch' onhub && ! grep -q 'onto no branch' '$hub/bb/docs/backlog.md' && [ -z \"\$(git -C '$hub/bb' status --short)\" ]"
git -C "$hub/bb" checkout -q main
# A scheduled run's own checkout, on cloud or on no branch, is the one place a
# note is still written into the checkout itself (spec 023): it is what GitHub
# has, and the line rides the run's own push to cloud (3.22.0 pushed it to main
# by name, and since spec 017 that push would carry the run's untested work).
# The stand-in has no recipes of its own, so the suite's are pointed at it.
incloud() { env -u AI_BACKBONE_OFFLINE -u AI_BACKBONE JUST_JUSTFILE="$root/Justfile" JUST_WORKING_DIRECTORY="$hub/cloud" "$@"; }
git -C "$hub/cloud" fetch -q origin main && git -C "$hub/cloud" checkout -q --detach origin/main
check "a scheduled run's checkout, which has no branch, saves a note that rides its push, and sends nothing itself" "says 'rides the next push to cloud' incloud just backbone-note 'core.just: idea: from a checkout with no branch' && grep -q 'from a checkout with no branch' '$hub/cloud/docs/backlog.md' && ! says 'from a checkout with no branch' onhub && says '^docs: backlog note' git -C '$hub/cloud' log -1 --format=%s"
git -C "$hub/cloud" fetch -q origin cloud && git -C "$hub/cloud" checkout -q -B cloud origin/cloud
printf -- '- [ ] 2026-01-09, p: kept here earlier\n' > "$hub/cloud/.git/ai-backbone-notes-outbox"
cf="$hub/cloud/docs/backlog.md"
check "on the cloud branch inside the backbone, the line goes into the checkout with the notes kept there above it, told once it is public" "o=\$(incloud just backbone-note 'core.just: idea: on the cloud branch' 2>&1); grep -q 'rides the next push to cloud' <<<\"\$o\" && grep -q 'and 1 note(s) kept here' <<<\"\$o\" && [ \$(grep -c '^  public ' <<<\"\$o\") -eq 1 ] && [ ! -e '$hub/cloud/.git/ai-backbone-notes-outbox' ] && [ \$(grep -n 'kept here earlier' '$cf' | cut -d: -f1) -lt \$(grep -n 'on the cloud branch' '$cf' | cut -d: -f1) ] && ! says 'on the cloud branch' onhub && says '^docs: backlog note' git -C '$hub/cloud' log -1 --format=%s"
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
( cd "$hub/agent" && git fetch -q origin && git push -q origin origin/main:refs/heads/cloud; cd "$hub" && git clone -q remote.git cc && git -C cc checkout -q cloud ) >/dev/null 2>&1
oncloud() { ( cd "$hub/agent" && git fetch -q origin cloud && git checkout -q -B cloud origin/cloud && eval "$1" && git add -A && git commit -qm "${2:-feat: on cloud}" && git push -q origin cloud && git checkout -q main ) >/dev/null 2>&1; }
( cd "$hub/cc" && echo local >> README.md && git commit -qam "feat: saved on cloud here" ) >/dev/null 2>&1
oncloud "echo theirs > theirs.txt"
onmain "printf -- '- [ ] 2026-01-08, agent: eighth\n' >> docs/backlog.md"   # main alone: the one thing a clone on cloud never pulls
check "a clone on cloud takes what is new there by a merge, never pulls main, and pushes nothing" "says 'pulled 1 new commit' online just _backbone-level '$hub/cc' GitHub && [ -n \"\$(git -C '$hub/cc' log --merges -1 --format=%h)\" ] && [ ! -d '$hub/cc/.git/rebase-merge' ] && ! grep -q 'agent: eighth' '$hub/cc/docs/backlog.md' && says 'not on GitHub yet -> just publish' online just _backbone-level '$hub/cc' GitHub && ! says 'saved on cloud here' git -C '$hub/remote.git' log --format=%s cloud"
check "from a project, a sibling on cloud is named and left alone" "says \"on 'cloud', not on main, and what projects copy from it is untested\" env -u AI_BACKBONE_OFFLINE AI_BACKBONE='$hub/cc' just _backbone-refresh '$hub/cc'"
check "and template-update copies nothing from it"      "! env -u AI_BACKBONE_OFFLINE AI_BACKBONE='$hub/cc' just template-update && says 'Not updated: .* on .cloud., not on main' env -u AI_BACKBONE_OFFLINE AI_BACKBONE='$hub/cc' just template-update"
( cd "$hub/agent" && git checkout -q -B cloud origin/cloud && echo old > old.txt && git add -A && GIT_COMMITTER_DATE='2020-01-01T00:00:00Z' GIT_AUTHOR_DATE='2020-01-01T00:00:00Z' git commit -qm "feat: waiting at the gate" && git push -q origin cloud && git checkout -q main ) >/dev/null 2>&1
check "once cloud has been ahead of main for two days, both voices say so" "says 'cloud is [0-9]+ commit\(s\) ahead of main, the oldest [0-9]+ days old' online just _backbone-level '$hub/bb' GitHub && says 'Backbone: cloud is [0-9]+ commit' online just _backbone-refresh '$hub/bb'"
( cd "$hub/agent" && git fetch -q origin && git push -q -f origin origin/main:refs/heads/cloud && git checkout -q -B cloud origin/cloud && echo young > young.txt && git add -A && git commit -qm "feat: pushed today" && git push -q origin cloud && git checkout -q main ) >/dev/null 2>&1
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
# A save on main in the backbone puts that commit on cloud too. The remote
# stays untouched: publish is what sends cloud.
( cd "$hub/bb" && git branch -q -f cloud HEAD && echo z >> README.md ) >/dev/null 2>&1
check "a save on main in the backbone puts the commit on cloud, not only on main" "says 'on cloud as well' inbb just save 'docs: on cloud too' && [ \"\$(git -C '$hub/bb' rev-parse main)\" = \"\$(git -C '$hub/bb' rev-parse cloud)\" ] && ! says 'on cloud too' git -C '$hub/remote.git' log --format=%s main && ! says 'on cloud too' git -C '$hub/remote.git' log --format=%s cloud"
# session-start fetches the local stand-in for GitHub and fast-forwards.
# The save above left a commit only here. Put the clone back on GitHub's
# main first, or the new remote commit and this one diverge and nothing moves.
bbmain=$(git -C "$hub/remote.git" rev-parse main)
( cd "$hub/bb" && git checkout -q main && git reset -q --hard origin/main && git branch -q -f cloud origin/cloud ) >/dev/null 2>&1
( cd "$hub/agent" && git fetch -q origin && git checkout -q -B main origin/main && echo remote >> README.md && git commit -qam "docs: remote main" && git push -q origin main ) >/dev/null 2>&1
check "session-start fast-forwards a local main that is behind GitHub" "o=\$(inbb just session-start 2>&1); ! grep -q 'GitHub: main is' <<<\"\$o\" && [ \"\$(git -C '$hub/bb' rev-parse main)\" = \"\$(git -C '$hub/remote.git' rev-parse main)\" ]"
( cd "$hub/bb" && git checkout -q -B cloud origin/cloud && echo ahead >> README.md && git commit -qam "docs: cloud ahead" && git checkout -q main ) >/dev/null 2>&1
check "session-start warns when local cloud is ahead of GitHub" "says 'GitHub: cloud is [0-9]+ ahead, 0 behind' inbb just session-start"
( cd "$hub/bb" && echo aheadm >> README.md && git commit -qam "docs: main ahead" ) >/dev/null 2>&1
check "session-start warns when local main is ahead of GitHub" "says 'GitHub: main is [0-9]+ ahead, 0 behind' inbb just session-start"
# Offline stays quiet and moves nothing (the suite must not reach a server).
aheadsha=$(git -C "$hub/bb" rev-parse main)
check "session-start offline leaves a local main that is ahead of GitHub" "o=\$(env AI_BACKBONE_OFFLINE=1 JUST_JUSTFILE='$root/Justfile' JUST_WORKING_DIRECTORY='$hub/bb' just session-start 2>&1); ! grep -q 'GitHub:' <<<\"\$o\" && [ \"\$(git -C '$hub/bb' rev-parse main)\" = '$aheadsha' ]"
git -C "$hub/remote.git" update-ref refs/heads/main "$bbmain"
( cd "$hub/bb" && git fetch -q origin && git checkout -q main && git reset -q --hard origin/main && git branch -q -f cloud origin/cloud ) >/dev/null 2>&1
( cd "$hub/agent" && git fetch -q origin && git checkout -q -B main origin/main ) >/dev/null 2>&1

# spec 017: the gate. What passes on cloud reaches main, and nothing else does.
# A bare folder stands in for GitHub with main and cloud; `work` pushes to cloud
# the way a run does; `judge` is the promote job's checkout of main; a stand-in
# gh answers what the run's jobs said (the log lines in the shape of
# fixtures/gh-log-failed.txt). Nothing leaves the machine.
fi
if lane_wants gate; then
section "the gate: what passes on cloud reaches main"
# The win lane skips the budget, which is where the other lanes install this.
install_audit_standin
check "windows.yml runs the Windows suite when look says suite, and checks.yml keeps Linux and macOS" \
  "grep -q 'runs-on: windows-latest' '$root/.github/workflows/windows.yml' && grep -q 'name: suite (windows-latest)' '$root/.github/workflows/windows.yml' && grep -q 'timeout-minutes: 60' '$root/.github/workflows/windows.yml' && grep -q 'timeout-minutes: 44' '$root/.github/workflows/windows.yml' && grep -q 'actions/checkout@v7' '$root/.github/workflows/windows.yml' && grep -q 'gate.sh look' '$root/.github/workflows/windows.yml' && grep -q 'branches: \\[cloud\\]' '$root/.github/workflows/windows.yml' && ! grep -q 'windows-latest' '$root/.github/workflows/checks.yml' && grep -q 'ubuntu-latest' '$root/.github/workflows/checks.yml' && grep -q 'macos-latest' '$root/.github/workflows/checks.yml'"
check "ci-check accepts the windows workflow" "says 'ok    \\.github/workflows/windows\\.yml' just -f '$root/Justfile' -d '$root' ci-check && says 'ok    \\.github/workflows/checks\\.yml' just -f '$root/Justfile' -d '$root' ci-check"
check "promote.yml carries when checks or windows finishes, and the commits it writes take the identity from the Actions variables" \
  "grep -q 'workflows: \\[checks, windows\\]' '$root/.github/workflows/promote.yml' && grep -q 'vars.GATE_GIT_NAME' '$root/.github/workflows/promote.yml' && grep -q 'vars.GATE_GIT_EMAIL' '$root/.github/workflows/promote.yml' && grep -q 'GATE_WORKFLOW' '$root/.github/workflows/promote.yml' && ! grep -q 'github-actions' '$root/.github/workflows/promote.yml' && ! grep -q 'github-actions' '$root/.ai-backbone/gate.sh'"
export GATE_GIT_NAME="Gate Maker" GATE_GIT_EMAIL="gate@example.com"
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
# windows.yml is a different run from the checks run (spec 037).
case "$*" in
  *windows.yml*) printf '%s\n' "${FAKE_WINDOWS:-}"; exit 0 ;;
  *"run list"*) printf '%s\n' "${FAKE_RUN:-}"; exit 0 ;;
esac
jobs="${FAKE_JOBS:-}"
log="${FAKE_LOG:-}"
winid=$(printf '%s' "${FAKE_WINDOWS:-}" | cut -f1)
if [ -n "$winid" ]; then
  for a in "$@"; do
    if [ "$a" = "$winid" ]; then jobs="${FAKE_WIN_JOBS:-$jobs}"; log="${FAKE_WIN_LOG:-$log}"; break; fi
  done
fi
case "$*" in
  *"--json jobs"*) printf '%s\n' "$jobs" | tr '|' '\n' ;;
  *"--log-failed"*) printf '%s\n' "$log" | tr '|' '\n' ;;
esac
EOF
chmod +x "$gt/gh/gh"
TAB=$'\t'
gate()     { ( cd "${1:-$gt/work}" && bash "$root/.ai-backbone/gate.sh" look 2>/dev/null | tail -1 ); }
pushed()   { ( cd "$gt/work" && eval "$1" >/dev/null && git add -A && git commit -qm "${2:-feat: on cloud}" && git push -q origin HEAD:cloud && git rev-parse HEAD ) 2>/dev/null; }
judge()    { ( cd "$gt/judge" && env PATH="$gt/gh:$PATH" FAKE_JOBS="${3:-}" FAKE_LOG="${4:-}" FAKE_WINDOWS="${FAKE_WINDOWS:-}" FAKE_WIN_JOBS="${FAKE_WIN_JOBS:-}" FAKE_WIN_LOG="${FAKE_WIN_LOG:-}" FAKE_RUN="${FAKE_RUN:-}" GATE_WORKFLOW="${GATE_WORKFLOW:-}" GATE_SHA="$1" GATE_ENDED="$2" GATE_RUN=77 bash "$root/.ai-backbone/gate.sh" carry ); }
# The attended carry (spec 031), from the person's clone; FAKE_RUN is the
# newest checks run of the commit, the way gh run list prints it.
attend()   { ( cd "$gt/work" && env -u GATE_RUN PATH="$gt/gh:$PATH" FAKE_JOBS="${2:-}" FAKE_RUN="${3-77${TAB}completed${TAB}success}" FAKE_WINDOWS="${FAKE_WINDOWS:-}" FAKE_WIN_JOBS="${FAKE_WIN_JOBS:-}" FAKE_WIN_LOG="${FAKE_WIN_LOG:-}" bash "$root/.ai-backbone/gate.sh" attend "$1" ); }
hubmain()  { git -C "$gt/hub.git" rev-parse main; }
hubtag()   { git -C "$gt/hub.git" rev-parse -q --verify "refs/tags/$1" 2>/dev/null; }
cloudlog() { git -C "$gt/hub.git" show cloud:docs/routine-log.md; }
loglines() { awk 'END { print NR }' <<<"$(cloudlog)"; }
synced()   { git -C "$gt/work" pull -q --no-rebase origin cloud >/dev/null 2>&1; }
GREEN="1${TAB}look${TAB}success|2${TAB}suite (ubuntu-latest)${TAB}success|3${TAB}suite (macos-latest)${TAB}success|4${TAB}suite (windows-latest)${TAB}success"
WINRED="1${TAB}look${TAB}success|2${TAB}suite (ubuntu-latest)${TAB}success|3${TAB}suite (macos-latest)${TAB}success|4${TAB}suite (windows-latest)${TAB}failure"
s=$(pushed "echo '- a log line' >> docs/routine-log.md && echo '- [ ] a note' >> docs/backlog.md && echo z > docs/radar.toml && mkdir -p docs/specs && echo s > docs/specs/099-x.md" "docs: the routine's own files")
check "look: a push that changes only the routine's own files is docs-only" "[ \"\$(gate)\" = docs-only ]"
check "carry: and the gate carries it to main on its own" "says 'carried .* to main' judge $s success '1${TAB}look${TAB}success' && [ \$(hubmain) = $s ]"
git clone -q --depth 1 -b cloud "$gt/hub.git" "$gt/shallow" >/dev/null 2>&1
check "and a checkout of depth one answers the same"   "[ \"\$(gate '$gt/shallow')\" = docs-only ]"
s=$(pushed "echo g > docs/01-getting-started.md" "docs: a page the suite reads")
check "look: any other page under docs/ runs the suite" "[ \"\$(gate)\" = suite ]"
( cd "$gt/shallow" && git fetch -q --depth 1 origin cloud && git checkout -q FETCH_HEAD ) >/dev/null 2>&1
check "in a checkout of depth one too"                  "[ \"\$(gate '$gt/shallow')\" = suite ]"
s=$(pushed "echo code >> README.md" "feat: code, Windows not started")
check "look: code runs the suite"                       "[ \"\$(gate)\" = suite ]"
# 2026-11-12: Linux and macOS green carries. Windows not started writes no line.
# The version bump below is a fresh commit, so attend still has something off main.
lines=$(loglines)
check "and the backbone's session start names what waits" "git -C '$gt/work' fetch -q origin && says '^Gate: cloud holds code main does not have.*once Linux and macOS are green -> just carry\$' env JUST_JUSTFILE='$root/Justfile' JUST_WORKING_DIRECTORY='$gt/work' just _gate-waits"
check "carry: green code is carried while Windows has not finished, and writes no line" "says 'carried .* to main' judge $s success '$GREEN' && [ \$(hubmain) = $s ] && [ \$(loglines) -eq $lines ] && ! says 'windows red' cloudlog && ! says 'not promoted' cloudlog"
s=$(pushed "printf '# .ai-backbone/core.just — recipes, version 1.0.1\n' > .ai-backbone/core.just" "feat: 1.0.1")
check "attend: a commit still being tested is refused" "says 'still going' attend $s '$GREEN' '77${TAB}in_progress${TAB}' && [ \$(hubmain) != $s ]"
MACRED="1${TAB}look${TAB}success|2${TAB}suite (ubuntu-latest)${TAB}success|3${TAB}suite (macos-latest)${TAB}failure"
check "attend: one not green on Linux and macOS is refused, and says why" "says 'not green on Linux and macOS' attend $s '$MACRED' && [ \$(hubmain) != $s ]"
check "attend: one with no checks run is refused" "says 'no checks run was found' attend $s '$GREEN' '' && [ \$(hubmain) != $s ]"
check "attend: a commit that is not on cloud is refused" "says 'not on cloud' attend \$(cd '$gt/work' && git commit -q --allow-empty -m local && git rev-parse HEAD) '$GREEN'"
( cd "$gt/work" && git reset -q --hard origin/cloud ) >/dev/null 2>&1
check "attend: a green commit on cloud is carried to main and its version tagged, in one push" "says 'carried ${s:0:7} to main and tagged v1.0.1' attend $s '$GREEN' && [ \$(hubmain) = $s ] && [ \"\$(hubtag v1.0.1)\" = $s ]"
check "and once there, the session start is quiet about it" "git -C '$gt/work' fetch -q origin && [ -z \"\$(env JUST_JUSTFILE='$root/Justfile' JUST_WORKING_DIRECTORY='$gt/work' just _gate-waits)\" ]"
synced; lines=$(loglines)
check "carried again, it says so and writes nothing"    "says 'on main already' judge $s success '$GREEN' && [ \$(loglines) -eq $lines ]"
s=$(pushed "echo y >> README.md" "feat: red")
check "a cancelled run is not judged"                   "says 'was cancelled' judge $s cancelled && [ \$(hubmain) != $s ] && [ \$(loglines) -eq $lines ]"
# Spec 037, and 2026-11-12: a Windows job still inside the checks run is ignored.
# Linux and macOS green is a carry. windows.yml is a different run; with none
# started, no windows line is written. Each case pushes its own commit, because
# the carry moves main and the next case would otherwise already be there.
CUT="1${TAB}look${TAB}success|2${TAB}suite (ubuntu-latest)${TAB}success|3${TAB}suite (macos-latest)${TAB}success|4${TAB}suite (windows-latest)${TAB}cancelled"
s=$(pushed "echo cut >> README.md" "feat: windows cut by its cap")
lines=$(loglines)
check "a windows job cancelled in the checks run is ignored: Linux and macOS carry, and no windows line is written" "o=\$(judge $s cancelled '$CUT' 2>&1); grep -q 'every suite job was green: they decide' <<<\"\$o\" && grep -q 'carried .* to main' <<<\"\$o\" && ! grep -q 'not promoted' <<<\"\$o\" && ! grep -q 'windows red' <<<\"\$o\" && [ \$(hubmain) = $s ] && [ \$(loglines) -eq $lines ]"
s=$(pushed "echo winred >> README.md" "feat: red windows job in the checks run")
lines=$(loglines)
check "and a red windows job in the checks run is ignored the same way" "o=\$(judge $s failure '$WINRED' 2>&1); grep -q 'every suite job was green: they decide' <<<\"\$o\" && grep -q 'carried .* to main' <<<\"\$o\" && ! grep -q 'not promoted' <<<\"\$o\" && ! grep -q 'windows red' <<<\"\$o\" && [ \$(hubmain) = $s ] && [ \$(loglines) -eq $lines ]"
GHOST="1${TAB}look${TAB}success|2${TAB}suite (ubuntu-latest)${TAB}success|3${TAB}suite (macos-latest)${TAB}success|4${TAB}suite (windows-latest)${TAB}success|5${TAB}something else${TAB}cancelled"
s=$(pushed "echo ghost >> README.md" "feat: cancelled by a job that is not a suite job")
lines=$(loglines)
check "a run cancelled by a job that is not a suite job, with Linux and macOS green, is carried and does not wait for Windows" "o=\$(judge $s cancelled '$GHOST' 2>&1); grep -q 'every suite job was green: they decide' <<<\"\$o\" && grep -q 'carried .* to main' <<<\"\$o\" && ! grep -q 'not promoted' <<<\"\$o\" && [ \$(hubmain) = $s ] && [ \$(loglines) -eq $lines ]"
s=$(pushed "echo attend >> README.md" "feat: attended after that carry")
check "attend: and an attended carry takes it"            "says 'carried .* to main' attend $s '$GHOST' && [ \$(hubmain) = $s ]"
synced; lines=$(loglines); s=$(pushed "echo y2 >> README.md" "feat: red again")   # cloud is unchanged by a carry; the count is taken after the pull anyway
RED="1${TAB}look${TAB}success|2${TAB}suite (ubuntu-latest)${TAB}success|9${TAB}suite (macos-latest)${TAB}failure|10${TAB}suite (windows-latest)${TAB}failure"
LOG="suite (macos-latest)${TAB}the suite${TAB}2026-01-02T03:00:00Z   FAIL  a mac check|suite (macos-latest)${TAB}the suite${TAB}2026-01-02T03:00:01Z   FAIL  another one|suite (windows-latest)${TAB}the suite${TAB}2026-01-02T03:00:02Z   FAIL  windows noise"
check "a red run writes one line on cloud naming each red machine and its FAIL names" "says 'not promoted' judge $s failure '$RED' '$LOG' && [ \$(loglines) -eq $((lines+1)) ] && says '^- [0-9-]+ gate: cloud not promoted — the checks ended failure: suite \(macos-latest\) failure FAIL: a mac check;another one; suite \(windows-latest\) failure FAIL: windows noise;\$' cloudlog && [ \$(hubmain) != $s ]"
check "a gate line is committed as the GATE_GIT identity" "[ \"\$(git -C '$gt/hub.git' log -1 --format='%an %ae' cloud)\" = 'Gate Maker gate@example.com' ]"
# Spec 037: carry prints the windows.yml run; a red one appends one gate: line.
synced
s=$(pushed "echo wcases >> README.md" "feat: windows cases")
check "carry prints a green windows run" "FAKE_WINDOWS='88${TAB}completed${TAB}success' says '^Windows: green$' attend $s '$MACRED' && [ \$(hubmain) != $s ]"
check "carry prints a windows run that is still going" "FAKE_WINDOWS='88${TAB}in_progress${TAB}' says '^Windows: running$' attend $s '$MACRED' && [ \$(hubmain) != $s ]"
check "carry prints none when the commit has no windows run" "says '^Windows: none$' attend $s '$MACRED' && [ \$(hubmain) != $s ]"
W6=""
for n in one two three four five six; do
  W6="${W6:+$W6|}suite (windows-latest)${TAB}step${TAB}t   FAIL  $n"
done
out=$(FAKE_WINDOWS="88${TAB}completed${TAB}failure" FAKE_WIN_JOBS="4${TAB}suite (windows-latest)${TAB}failure" FAKE_WIN_LOG="$W6" attend $s "$MACRED" 2>&1)
check "carry prints a red windows run with at most five FAIL names" "grep -q '^Windows: red: suite (windows-latest) failure FAIL: one;two;three;four;five;\$' <<<\"\$out\" && ! grep -q 'six' <<<\"\$out\" && [ \$(hubmain) != $s ]"
lines=$(loglines)
FAKE_WIN_JOBS="4${TAB}suite (windows-latest)${TAB}failure"
FAKE_WIN_LOG="suite (windows-latest)${TAB}the suite${TAB}2026-01-02T03:00:02Z   FAIL  a windows check"
check "a red windows run is carried and writes one windows gate line (2026-11-12: Windows reports, it does not hold main back)" "FAKE_WINDOWS='88${TAB}completed${TAB}failure' says 'carried .* to main' judge $s success '$GREEN' && [ \$(hubmain) = $s ] && [ \$(loglines) -eq $((lines+1)) ] && says '^- [0-9-]+ gate: windows red on [0-9a-f]+, which Linux and macOS judged — suite \\(windows-latest\\) failure FAIL: a windows check;\$' cloudlog"
unset FAKE_WIN_JOBS FAKE_WIN_LOG
synced; lines=$(loglines)
wrun=$(grep -c 'windows run ended' <<<"$(cloudlog)" || true)
s=$(pushed "echo winrun >> README.md" "feat: windows still running")
check "a windows run that is still going does not hold the carry and adds no gate line" "FAKE_WINDOWS='88${TAB}in_progress${TAB}' says 'carried .* to main' judge $s success '$GREEN' && [ \$(loglines) -eq $lines ] && [ \$(grep -c 'windows run ended' <<<\"\$(cloudlog)\" || true) -eq $wrun ] && [ \$(hubmain) = $s ]"
synced; s=$(pushed "echo 'on: pull_request' > .github/workflows/checks.yml" "ci: weaken")
check "a push that changes the workflows is carried when Linux and macOS are green, without waiting for Windows" "says 'carried .* to main' judge $s success '$GREEN' && [ \$(hubmain) = $s ]"
synced; s=$(pushed "git checkout origin/main -- .github/workflows && echo '# x' >> .ai-backbone/gate.sh" "ci: weaken the judge")
check "and so is one that changes gate.sh, without waiting for Windows" "says 'carried .* to main' judge $s success '$GREEN' && [ \$(hubmain) = $s ]"
synced; s=$(pushed "git checkout origin/main -- .ai-backbone/gate.sh && echo w >> README.md" "feat: code")
check "a green run whose suite never ran is refused: a look weakened on cloud passes no code" "says 'suite was due' judge $s success '1${TAB}look${TAB}success' && [ \$(hubmain) != $s ]"
# gh answers nothing while GitHub is still processing a run's results (2026-10-22:
# an hour of delayed Actions results, and the gate wrote "no green suite job" for
# a run whose two suites were green). The line must say what was read, not what
# the run was.
check "a run whose jobs could not be read says so, not that the suite never ran" "says 'jobs could not be read' judge $s success '' && [ \$(hubmain) != $s ] && says '^- [0-9-]+ gate: cloud not promoted — the suite was due for this push and the run.s jobs could not be read \(run 77\); the next push is judged instead\$' cloudlog"
( cd "$gt" && git clone -q hub.git other && cd other && echo '- [ ] 2026-01-03, p: a note' >> docs/backlog.md && git add -A && git commit -qm "docs: backlog note from p" && git push -q origin main ) >/dev/null 2>&1
check "main that moved is not fast-forwarded, and the line says what joins them" "says 'main moved' judge $s success '$GREEN' && [ \$(hubmain) != $s ] && says 'the next run merges origin/main into cloud' cloudlog"
check "attend: a commit main has moved past is refused, and says to merge" "says 'merge origin/main into cloud' attend $s '$GREEN' && [ \$(hubmain) != $s ]"
synced; s=$( cd "$gt/work" && git fetch -q origin main && git merge -q --no-edit origin/main >/dev/null 2>&1 && git push -q origin HEAD:cloud && git rev-parse HEAD )
check "after the run merged main into cloud, a green Windows run carries it" "FAKE_WINDOWS='88${TAB}completed${TAB}success' says 'carried .* to main' judge $s success '$GREEN' && [ \$(hubmain) = $s ]"
git -C "$gt/hub.git" tag v1.0.2 "$(git -C "$gt/hub.git" rev-parse 'main~2')" >/dev/null 2>&1
synced; s=$(pushed "printf '# .ai-backbone/core.just — recipes, version 1.0.2\n' > .ai-backbone/core.just" "feat: 1.0.2")
check "a tag GitHub has elsewhere is left alone and main is carried on its own" "says 'carried .* to main; v1.0.2 was tagged before' attend $s '$GREEN' && [ \$(hubmain) = $s ] && [ \"\$(hubtag v1.0.2)\" != $s ]"
synced; s=$(pushed "printf '# .ai-backbone/core.just — recipes, version 1.0.3\n' > .ai-backbone/core.just" "feat: 1.0.3")
check "carry: green on Linux and macOS carries code and tags the version, without waiting for Windows" "says 'carried .* to main and tagged v1.0.3' judge $s success '$GREEN' && [ \$(hubmain) = $s ] && [ \"\$(hubtag v1.0.3)\" = $s ]"
synced; s=$(pushed "echo '# changed' >> .ai-backbone/gate.sh" "ci: the gate itself")
inwork()   { env PATH="$gt/gh:$PATH" JUST_JUSTFILE="$root/Justfile" JUST_WORKING_DIRECTORY="$gt/work" "$@"; }
check "just carry is the backbone's own: no project gets it" "grep -q '^carry ' '$root/Justfile' && ! grep -q '^carry ' '$root/.ai-backbone/core.just' '$root/.ai-backbone/seed/Justfile'"
check "a green change to gate.sh is carried when Windows is green" "FAKE_WINDOWS='88${TAB}completed${TAB}success' says 'carried .* to main' judge $s success '$GREEN' && [ \$(hubmain) = $s ]"
synced; s=$(pushed "echo '# changed again' >> .ai-backbone/gate.sh" "ci: the gate itself again")
check "attend: a green change to gate.sh is named" "says 'carried .* to main.*; it changed the gate.s own files: \.ai-backbone/gate\.sh\$' attend $s '$GREEN' && [ \$(hubmain) = $s ]"
synced; s=$(pushed "echo '# readme' > README.md" "feat: the backbone's own readme")
check "just carry lists the code that waits and, when it is green, the commit to carry" "says 'once Linux and macOS are green' inwork just carry && says \"  ${s:0:7} feat: the backbone's own readme\" inwork just carry && says '^Checks: ${s:0:7} is green -> just carry ${s:0:7}\$' inwork env FAKE_RUN='completed success' just carry"
check "and just carry <commit> takes it to main with main's own gate.sh and prints the windows line" "out=\$(inwork env FAKE_RUN='77${TAB}completed${TAB}success' FAKE_JOBS='$GREEN' FAKE_WINDOWS='88${TAB}completed${TAB}success' just carry $s 2>&1); grep -q 'carried ${s:0:7} to main' <<<\"\$out\" && grep -q '^Windows: green$' <<<\"\$out\" && [ \$(hubmain) = $s ]"
check "after which nothing waits"                       "says '^Nothing waits' inwork just carry"
synced; lines=$(loglines); s=$(pushed "echo trig >> README.md && printf '# .ai-backbone/core.just — recipes, version 1.0.4\n' > .ai-backbone/core.just" "feat: 1.0.4")
check "when windows finishes and the checks have not, nothing is written" "GATE_WORKFLOW=windows says 'checks have not' judge $s success '$GREEN' && [ \$(hubmain) != $s ] && [ \$(loglines) -eq $lines ]"
check "when windows finishes after green checks, the code is carried and tagged" "GATE_WORKFLOW=windows FAKE_RUN='77${TAB}completed${TAB}success' FAKE_WINDOWS='88${TAB}completed${TAB}success' says 'carried .* to main and tagged v1.0.4' judge $s failure '$GREEN' && [ \$(hubmain) = $s ] && [ \"\$(hubtag v1.0.4)\" = $s ]"
synced; s=$(pushed "echo '1.0.0 0000000' > STABLE" "chore: mark 1.0.0 stable")
check "a push that moves the stable mark is never carried on its own" "FAKE_WINDOWS='88${TAB}completed${TAB}success' says 'STABLE' judge $s success '$GREEN' && [ \$(hubmain) != $s ] && says 'it changes STABLE' cloudlog && ! says 'waits for an attended carry' cloudlog"

# spec 031: projects move on a stable version. A bare folder stands in for
# GitHub with two tagged versions; bb is the backbone next to the project.
fi
if lane_wants stable; then
section "the stable mark (spec 031)"
sm="$tmp/stable"; mkdir -p "$sm/seed"
( cd "$root" && git ls-files -z | xargs -0 tar -cf - 2>/dev/null ) | tar -xf - -C "$sm/seed" 2>/dev/null
setv() { perl -0pi -e "s/version [0-9]+\\.[0-9]+\\.[0-9]+/version \$ENV{V}/" "$sm/seed/.ai-backbone/core.just"; }
( cd "$sm" && git init -q --bare -b main hub.git && cd seed && git init -qb main && V=1.0.0 setv && git add -A && git commit -qm "chore: 1.0.0" --no-verify && git tag v1.0.0 \
  && echo '<!-- 1.0.1 -->' >> .ai-backbone/templates/spec.md && V=1.0.1 setv && git commit -qam "feat: 1.0.1" --no-verify && git tag v1.0.1 \
  && git remote add origin ../hub.git && git push -q origin main --tags && git push -q origin main:cloud && cd .. && git clone -q hub.git bb ) >/dev/null 2>&1
( cd "$sm/bb" && git checkout -q v1.0.0 && just new-project "$sm/proj" && git checkout -q main ) >/dev/null 2>&1
( cd "$sm/proj" && git add -A && git commit -qm "chore: start" --no-verify ) >/dev/null 2>&1
smon()   { ( cd "$sm/proj" && env -u AI_BACKBONE_OFFLINE AI_BACKBONE="$sm/bb" "$@" ); }
mark()   { ( cd "$sm/seed" && printf '%s %s\n' "$1" "$(git rev-parse "${2:-v$1}")" > STABLE && git add STABLE && git commit -qm "chore: stable $1" --no-verify && git push -q origin main ) >/dev/null 2>&1; }
projv()  { sed -n '1s/.*version \([0-9][0-9.]*\).*/\1/p' "$sm/proj/.ai-backbone/core.just"; }
check "with no mark, a project hears behind the newest, as before" "[ \"\$(projv)\" = 1.0.0 ] && says '^Backbone: 1\.0\.0 -> 1\.0\.1, [0-9]+ file\(s\) behind' smon just template-check"
mark 1.0.0
check "marked stable below the newest, it is up to date and says what is newer" "says '^Backbone: up to date \(1\.0\.0; 1\.0\.1 is newer, not marked stable yet\)' smon just template-check"
check "and template-update goes to the mark, copying nothing newer" "says 'To 1\.0\.0, the version marked stable' smon just template-update && [ \"\$(projv)\" = 1.0.0 ] && ! grep -q '1.0.1 -->' '$sm/proj/.ai-backbone/templates/spec.md'"
check "template-update newest goes past it"            "smon just template-update newest >/dev/null 2>&1; [ \"\$(projv)\" = 1.0.1 ] && grep -q '1.0.1 -->' '$sm/proj/.ai-backbone/templates/spec.md'"
( cd "$sm/proj" && git add -A && git commit -qm "chore: backbone 1.0.1" --no-verify ) >/dev/null 2>&1
check "a project past the mark is told it is ahead, never behind or broken" "says '^Backbone: 1\.0\.1, ahead of 1\.0\.0, the version marked stable' smon just template-check"
check "and template-update never takes it back down"   "says 'Already past 1\.0\.0' smon just template-update && [ \"\$(projv)\" = 1.0.1 ]"
mark 1.0.0 v1.0.1
check "a mark whose commit does not carry its version is not read" "says '^Backbone: up to date \(1\.0\.1\)' smon just template-check"
( cd "$sm/proj" && git reset -q --hard HEAD~1 ) >/dev/null 2>&1
mark 1.0.1
check "once the newest is marked, behind means behind it" "says '^Backbone: 1\.0\.0 -> 1\.0\.1, [0-9]+ file\(s\) behind' smon just template-check"
( cd "$sm/seed" && echo '<!-- 1.0.2 -->' >> .ai-backbone/templates/adr.md && V=1.0.2 setv && git commit -qam "feat: 1.0.2" --no-verify && git tag v1.0.2 && git push -q origin main --tags ) >/dev/null 2>&1
check "a project below the mark hears behind the mark, not the newest" "says '^Backbone: 1\.0\.0 -> 1\.0\.1 \(stable\), [0-9]+ file\(s\) behind' smon just template-check"
check "and template-update takes it to the mark exactly" "smon just template-update >/dev/null 2>&1; [ \"\$(projv)\" = 1.0.1 ] && grep -q '1.0.1 -->' '$sm/proj/.ai-backbone/templates/spec.md' && ! grep -q '1.0.2 -->' '$sm/proj/.ai-backbone/templates/adr.md'"
( cd "$sm/proj" && git checkout -q -- . && git clean -qfd ) >/dev/null 2>&1
mark 1.0.0
check "offline, no mark is read: behind the newest"     "says '^Backbone: 1\.0\.0 -> 1\.0\.2, ' smon env AI_BACKBONE_OFFLINE=1 just template-check"
check "just stable writes the mark from the version's tag, and refuses one that never reached main" "( cd '$sm/bb' && git fetch -q origin && git checkout -q -B main origin/main ) >/dev/null 2>&1; says 'STABLE now says 1\.0\.1' env -u AI_BACKBONE_OFFLINE JUST_JUSTFILE='$root/Justfile' JUST_WORKING_DIRECTORY='$sm/bb' just stable 1.0.1 && [ \"\$(cat '$sm/bb/STABLE')\" = \"1.0.1 \$(git -C '$sm/bb' rev-parse v1.0.1)\" ] && says 'No tag v9\.9\.9' env -u AI_BACKBONE_OFFLINE JUST_JUSTFILE='$root/Justfile' JUST_WORKING_DIRECTORY='$sm/bb' just stable 9.9.9 && grep -q 'Never write .STABLE.' '$root/.ai-backbone/routine.md'"
# CalVer numbers are read by the same numeric comparisons (spec 039): a mark
# takes 26.10.0, and 26.10.0 is newer than the last SemVer 3.46.0.
( cd "$sm/seed" && V=26.10.0 setv && git commit -qam "feat: 26.10.0" --no-verify && git tag v26.10.0 && git push -q origin main --tags ) >/dev/null 2>&1
check "just stable takes a CalVer number" "says 'STABLE now says 26\\.10\\.0' env -u AI_BACKBONE_OFFLINE JUST_JUSTFILE='$root/Justfile' JUST_WORKING_DIRECTORY='$sm/bb' just stable 26.10.0 && [ \"\$(cut -d' ' -f1 '$sm/bb/STABLE')\" = 26.10.0 ]"
check "CalVer 26.10.0 reads as newer than the last SemVer 3.46.0" "just _newer 26.10.0 3.46.0 && ! just _newer 3.46.0 26.10.0 && just _newer 27.1.0 26.10.9"
check "the backbone's own version is CalVer, and reads newer than 3.46.0" "bv=\$(sed -n '1s/.*version //p' '$root/.ai-backbone/core.just') && case \"\$bv\" in 2[0-9].[0-9]*.[0-9]*) ;; *) exit 1 ;; esac && just _newer \"\$bv\" 3.46.0"
# spec 013, session-tools: what session-start says and what it remembers, the pin
# tools-update moves, and the Go hooks-install fetches when prek cannot. In a
# throwaway project of its own, so the checks around this block find the first
# one as they left it.
fi
if lane_wants session; then
section "session-start, tools-update and hooks-install (spec 013)"
st="$tmp/session-tools"
( cd "$root" && just new-project "$st" ) >/dev/null 2>&1
cd "$st" || exit 1
# The specs that are open. Until now a session began with the journal, the
# commits and the backlog, and nothing said that a spec was half built.
check "session-start is quiet about specs while none is open" "says '^=== LAST COMMITS' just session-start && ! says '^Spec |docs/specs' just session-start"
just spec 'first idea' >/dev/null 2>&1
printf -- '---\nstatus: approved\n---\n\n# 002\n\n## Acceptance\n\n- [ ] never counted\n\n## Tasks\n\n- [x] one\n- [~] half done, which is open: it runs\n      on to a second line\n- [ ] three\n' > docs/specs/002-second.md
printf -- '---\nstatus: done\n---\n\n# 003\n\n## Tasks\n\n- [ ] left open in a finished spec\n' > docs/specs/003-finished.md
printf -- '---\nstatus: approved\nnight: yes\n---\n\n# 004\n\n## Tasks\n\n- [ ] the first of the night\n' > docs/specs/004-tonight.md
out=$(just session-start 2>&1)
check "session-start names each open spec, how far it is, and its next task" "grep -q '^Spec 001-first-idea (draft, no code until approved): 0 of 1 tasks ticked\\. Next: Small steps' <<<\"\$out\" && grep -q '^Spec 002-second (approved): 1 of 3 tasks ticked\\. Next: half done, which is open: it runs …\$' <<<\"\$out\""
check "a night spec says so on its line"               "grep -q '^Spec 004-tonight (approved, night spec): 0 of 1 tasks ticked\\. Next: the first of the night\$' <<<\"\$out\" && ! grep -q '^Spec 002-second (approved, night' <<<\"\$out\""
check "and leaves a finished spec out"                 "grep -q '^Spec 002' <<<\"\$out\" && ! grep -q '003-finished' <<<\"\$out\""
# No GitHub address, no second copy of the code. It asks git only, so the offline
# suite hears it too; the address below is never asked for anything.
check "a project with no GitHub address hears so at every session, offline too" "grep -q '^GitHub: no address yet.* -> just publish\$' <<<\"\$out\""
git remote add origin https://github.com/example/no-such-repo.git
check "and no longer once it has one"                  "says '^=== LAST COMMITS' just session-start && ! says '^GitHub: no address' just session-start"
git remote remove origin
# n-e45338: publish-on-save unset or false, and main many commits ahead of
# origin/main. Said at 10, with the count and the fix, inside WORKING TREE.
# Quiet below 10, quiet when the setting is true, quiet when origin is gone.
publish_ahead_line() {
  local out n
  out=$(just session-start 2>&1)
  n=$(awk -v count="$1" '
    /^=== WORKING TREE ===/ { b = 1; next }
    /^=== / { b = 0 }
    b && index($0, "main is " count " commits ahead of origin/main") && index($0, "git config ai-backbone.publish-on-save true; just publish") { c++ }
    END { print c + 0 }
  ' <<<"$out")
  [ "$n" = 1 ]
}
pubbase=$(git rev-parse HEAD)
git init -q --bare -b main "$tmp/pub-origin.git"
git remote add origin "$tmp/pub-origin.git"
git push -q origin main
git fetch -q origin
pubn=1
while [ "$pubn" -le 9 ]; do
  echo "$pubn" >> pub-ahead.txt
  git add pub-ahead.txt
  git commit -qm "chore: ahead $pubn" --no-verify
  pubn=$((pubn + 1))
done
check "nine commits ahead, publish-on-save unset, says nothing" "[ \"\$(git rev-list --count origin/main..main)\" = 9 ] && ! says 'commits ahead of origin/main' just session-start"
echo 10 >> pub-ahead.txt
git add pub-ahead.txt
git commit -qm "chore: ahead 10" --no-verify
check "ten ahead, publish-on-save unset: one line in WORKING TREE names the count and the fix" "publish_ahead_line 10"
git config ai-backbone.publish-on-save false
check "ten ahead with publish-on-save false says the same" "publish_ahead_line 10"
git config ai-backbone.publish-on-save true
check "publish-on-save true stays quiet however far main is" "! says 'commits ahead of origin/main' just session-start"
git config --unset ai-backbone.publish-on-save
git remote remove origin
check "no origin stays quiet, even when main has the commits" "! says 'commits ahead of origin/main' just session-start"
git reset -q --hard "$pubbase"
rm -f pub-ahead.txt
# The daily check replaced the weekly one (spec 035). These three lift the
# offline switch: there is no backbone nearby to bring level, the tool-release
# block is stamped so it does not ask, a proxy nothing listens on stands behind
# it all, and the only source is a kind upstream.py refuses before it asks
# anybody. A stand-in plays a check that could not run, and one that printed.
weekly() { env -u AI_BACKBONE_OFFLINE AI_BACKBONE="$tmp/none" https_proxy=$dead http_proxy=$dead no_proxy= just session-start; }
printf '[[watch]]\nname = "nowhere"\nsource = "nosuchkind:nothing"\npin = "1.0.0"\n' > docs/upstream.toml
touch .git/ai-backbone.last-check; rm -f .git/ai-backbone.last-upstream
check "a check that read nothing does not stamp a week" "says '=== FRESHNESS' weekly && says 'unknown source' weekly && says nowhere weekly && [ ! -e .git/ai-backbone.last-upstream ]"
printf 'raise SystemExit(1)\n' > .ai-backbone/upstream.py
check "nor does one that could not run, and it says so"  "says '^upstream: could not run' weekly && [ ! -e .git/ai-backbone.last-upstream ]"
printf 'print("Everything watched is current.")\n' > .ai-backbone/upstream.py
check "a session shows what the check printed and does not stamp a week" "says '^Everything watched' weekly && [ ! -e .git/ai-backbone.last-upstream ]"
cp "$root/.ai-backbone/upstream.py" .ai-backbone/upstream.py; rm -f docs/upstream.toml .git/ai-backbone.last-check .git/ai-backbone.last-upstream
# tools-update upgraded graphify and left its pin behind: 0.9.62 in the list, 0.9.64
# installed. Every tool is a stand-in and brew is off the PATH, as in the two
# tools-update checks above. Four rows: one to move, one a file holds, one a file
# holds with its keys in another order, one that is ahead of what is installed.
tu="$tmp/st-tools"; mkdir -p "$tu/bin" "$tu/work/docs"; ln -sf "$(command -v just)" "$tu/bin/just"
printf '#!/bin/sh\n[ "$1" = --version ] && echo "uv 0.12.19 (x 2026-09-25)"\nexit 0\n' > "$tu/bin/uv"
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

[[watch]]
name = "installer"
source = "pypi:uv"
pin = "0.12.0"
TOML
cp "$tu/work/docs/upstream.toml" "$tu/before.toml"
tools_update() { env PATH="$tu/bin:/usr/bin:/bin" just -f "$root/Justfile" -d "$tu/work" tools-update; }
out=$(tools_update 2>&1)
check "tools-update moves the pin of a tool no file holds to what is installed, and says so" "grep -q '^docs/upstream.toml: map pin 0.9.62 -> 0.9.64' <<<\"\$out\" && grep -q '^pin = \"0.9.64\"   # by hand\$' '$tu/work/docs/upstream.toml'"
changed=$(diff "$tu/before.toml" "$tu/work/docs/upstream.toml")
check "a row read from PyPI moves too (spec 021)" "grep -q '^docs/upstream.toml: installer pin 0.12.0 -> 0.12.19' <<<\"\$out\""
check "and that one line only, once: not a pin a file holds, not one that is ahead" "[ \$(grep -c '^[<>]' <<<\"\$changed\") -eq 4 ] && ! says ' pin .* -> ' tools_update"
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
fi
if lane_wants radar; then
section "the radar"
# The routine runs every third day since 2026-10-07, and every second run looks
# outward: the last radar five days old or more.
rq="$tmp/radar-due"; git init -q "$rq"
due() { just -f "$root/Justfile" -d "$rq" radar-due; }
check "a history with no radar run is due one" "says '^yes: no radar run' due"
GIT_COMMITTER_DATE="$(( $(date +%s) - 3 * 86400 )) +0000" git -C "$rq" commit -q --allow-empty -m "docs: radar 2026-01-01" --no-verify
check "three days after a radar, a run does the ordinary work" "says '^no: the last radar was 3 day' due"
GIT_COMMITTER_DATE="$(( $(date +%s) - 6 * 86400 + 600 )) +0000" git -C "$rq" commit -q --allow-empty -m "docs: radar 2026-01-02" --no-verify
check "and a run a few minutes short of six days looks outward" "says '^yes: the last radar was 5 days ago' due"
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
fi
if lane_wants language; then
section "what the language needs, the update bot, the second copy"
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
  # Older than 24 hours is a warning that names the project and the age.
  # Reading it does not rewrite about-this-copy.txt. A fresh copy is the
  # ordinary line, and session-start does not warn about it (n-a931f8).
  vault_stale_kept() {
    local about="$copy/about-this-copy.txt" line
    line=$(grep '^Written by ' "$about")
    [ -n "$line" ] || { echo "no written line"; return 1; }
    vc repo_doctor > "$tmp/vault-stale-doc.txt" 2>&1 || true
    grep -qE '^  warn  deneme-projesi: ikinci kopya [0-9]+ günlük, yeri .*/deneme-projesi$' "$tmp/vault-stale-doc.txt" || { echo "stale doctor:"; cat "$tmp/vault-stale-doc.txt"; return 1; }
    grep -qxF "$line" "$about" || { echo "doctor rewrote the timestamp"; return 1; }
    vc just session-start > "$tmp/vault-stale-ss.txt" 2>&1 || { echo "session-start failed"; cat "$tmp/vault-stale-ss.txt"; return 1; }
    grep -qE '^Vault copy: deneme-projesi: ikinci kopya [0-9]+ günlük, yeri ' "$tmp/vault-stale-ss.txt" || { echo "stale session:"; cat "$tmp/vault-stale-ss.txt"; return 1; }
    vc repo_doctor > "$tmp/vault-fresh-doc.txt" 2>&1 || true
    grep -qE '^  ok    .*(less than a day old|bir günden yeni).*/second copies/deneme-projesi$' "$tmp/vault-fresh-doc.txt" || { echo "fresh doctor:"; cat "$tmp/vault-fresh-doc.txt"; return 1; }
    if grep -qE 'ikinci kopya [0-9]+ günlük' "$tmp/vault-fresh-doc.txt"; then echo "fresh doctor still says stale"; return 1; fi
    vc just session-start > "$tmp/vault-fresh-ss.txt" 2>&1 || { echo "fresh session-start failed"; cat "$tmp/vault-fresh-ss.txt"; return 1; }
    if grep -qE '^Vault copy: deneme-projesi:' "$tmp/vault-fresh-ss.txt"; then echo "fresh session warned"; return 1; fi
  }
  check "a stale vault is named with its age, and a fresh one is not" "vault_stale_kept"
  vault_rsync_fail_keeps_stamp() {
    local about="$copy/about-this-copy.txt" line out
    line=$(grep '^Written by ' "$about")
    mkdir -p "$tmp/fake-rsync"
    printf '#!/bin/sh\nexit 1\n' > "$tmp/fake-rsync/rsync"
    chmod +x "$tmp/fake-rsync/rsync"
    out=$(PATH="$tmp/fake-rsync:$PATH" vc just _vault-copy quiet 2>&1) || true
    grep -q 'brain/ was not copied in full' <<<"$out" || { echo "$out"; return 1; }
    grep -qxF "$line" "$about" || { echo "a failed copy rewrote the timestamp"; return 1; }
    vc just _vault-copy quiet >/dev/null 2>&1 || return 1
  }
  check "a failed copy keeps the timestamp in about-this-copy.txt" "vault_rsync_fail_keeps_stamp"
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
  # After a successful accept, that project's vault is copied. One line. Off
  # stays silent, and the accept still succeeds (n-a931f8).
  vault_accept_copies() {
    local acc="$tmp/vault-acc" out rc n
    mkdir -p "$acc/brain" "$acc/.ai-backbone"
    printf 'note\n' > "$acc/brain/note.md"
    printf 'brain/\n' > "$acc/.gitignore"
    printf '| project | vault-acc |\n' > "$acc/AGENTS.md"
    printf "import? '%s/.ai-backbone/core.just'\n" "$rootw" > "$acc/Justfile"
    printf '# stub\n' > "$acc/.ai-backbone/core.just"
    (
      cd "$acc" || exit 1
      git init -q -b main
      git add -A
      git commit -qm "chore: seed"
      git checkout -q -b delegate/vault-job
      printf 'line\n' >> README.md
      git add README.md
      git commit -qm "feat: a line"
      git checkout -q main
    ) || return 1
    out=$(vc just -f "$root/Justfile" -d "$acc" delegate-accept 2>&1) && rc=0 || rc=$?
    n=$(grep -c '^brain/ copied to ' <<<"$out" || true)
    [ "$rc" -eq 0 ] && grep -q '^accepted ' <<<"$out" && [ "$n" -eq 1 ] && [ -f "$place/vault-acc/brain/note.md" ] || {
      echo "rc=$rc copies=$n"; printf '%s\n' "$out" | tail -30; return 1
    }
    (
      cd "$acc" || exit 1
      git checkout -q -b delegate/vault-off
      printf 'two\n' >> README.md
      git add README.md
      git commit -qm "feat: two"
      git checkout -q main
    ) || return 1
    git -C "$acc" config --local ai-backbone.vault-copy off
    out=$(vc just -f "$root/Justfile" -d "$acc" delegate-accept 2>&1) && rc=0 || rc=$?
    [ "$rc" -eq 0 ] && grep -q '^accepted ' <<<"$out" && ! grep -q 'brain/ copied to' <<<"$out" || {
      echo "off rc=$rc"; printf '%s\n' "$out" | tail -30; return 1
    }
  }
  check "delegate-accept copies that project's vault, and off stays quiet" "vault_accept_copies"
  # Every sibling, the same list the backbone already uses. Off stays off.
  # The age is the copy's age before this run. A project with no brain/ is
  # not a line. The fixture is the whole list: this folder is not added.
  vault_sibling_sweep() {
    local vs="$tmp/vault-sib" name d out
    sib() { AI_BACKBONE_PROJECTS="$vs" vc "$@"; }
    mkdir -p "$vs"
    for name in one two three four five; do
      d="$vs/$name"
      mkdir -p "$d/.ai-backbone"
      printf '| project | %s |\n' "$name" > "$d/AGENTS.md"
      printf "import? '%s/.ai-backbone/core.just'\n" "$rootw" > "$d/Justfile"
      printf '# stub\n' > "$d/.ai-backbone/core.just"
      git -C "$d" init -q
    done
    for name in one two three four; do
      mkdir -p "$vs/$name/brain"
      printf 'note\n' > "$vs/$name/brain/note.md"
    done
    git -C "$vs/three" config --local ai-backbone.vault-copy off
    git -C "$vs/four" config --local ai-backbone.vault-copy "$tmp/vault-missing-place"
    mkdir -p "$place/one"
    printf 'old\n' > "$place/one/about-this-copy.txt"
    touch -t 202001010000 "$place/one/about-this-copy.txt"
    out=$(sib bash "$root/.ai-backbone/vault-sweep.sh" warn-others 2>&1) || true
    grep -qE '^Vault copy: one: the second copy is [0-9]+ days old, in ' <<<"$out" || { echo "warn: $out"; return 1; }
    if grep -qE '^Vault copy: (two|three|four|five):' <<<"$out"; then echo "warned a project that is not stale: $out"; return 1; fi
    sib repo_doctor > "$tmp/vault-sib-doc.txt" 2>&1 || true
    grep -qE '^  warn  Vault copy: one: the second copy is [0-9]+ days old, in ' "$tmp/vault-sib-doc.txt" || { echo "doctor:"; cat "$tmp/vault-sib-doc.txt"; return 1; }
    sib just session-start > "$tmp/vault-sib-ss.txt" 2>&1 || { echo "session-start:"; cat "$tmp/vault-sib-ss.txt"; return 1; }
    grep -qE '^Vault copy: one: the second copy is [0-9]+ days old, in ' "$tmp/vault-sib-ss.txt" || { echo "session:"; cat "$tmp/vault-sib-ss.txt"; return 1; }
    out=$(sib just vault-sweep 2>&1) || true
    grep -qE '^one: copied, was [0-9]+ days$' <<<"$out" || { echo "sweep: $out"; return 1; }
    grep -qE '^two: copied, was none$' <<<"$out" || { echo "sweep: $out"; return 1; }
    grep -qE '^three: off, was none$' <<<"$out" || { echo "sweep: $out"; return 1; }
    grep -qE '^four: failed, was none$' <<<"$out" || { echo "sweep: $out"; return 1; }
    if grep -q '^five:' <<<"$out"; then echo "a project with no brain/ was a line: $out"; return 1; fi
    [ -f "$place/one/brain/note.md" ] && [ -f "$place/two/brain/note.md" ] || { echo "copies missing"; return 1; }
    [ ! -e "$place/three/brain" ] && [ ! -e "$tmp/vault-missing-place" ] || { echo "off or failed was written"; return 1; }
    out=$(sib bash "$root/.ai-backbone/vault-sweep.sh" warn-others 2>&1) || true
    if grep -q '^Vault copy:' <<<"$out"; then echo "fresh siblings still warned: $out"; return 1; fi
    printf 'late\n' > "$vs/two/brain/late.md"
    out=$(AI_BACKBONE_PROJECTS="$vs" AI_BACKBONE_VAULT_STAMP="$tmp/vault-sweep.last" vc bash "$root/.ai-backbone/vault-sweep.sh" --periodic "$root" 2>&1) || true
    grep -qE '^two: copied, was ' <<<"$out" || { echo "periodic: $out"; return 1; }
    [ -f "$place/two/brain/late.md" ] || { echo "first periodic did not copy"; return 1; }
    printf 'later\n' > "$vs/two/brain/later.md"
    out=$(AI_BACKBONE_PROJECTS="$vs" AI_BACKBONE_VAULT_STAMP="$tmp/vault-sweep.last" vc bash "$root/.ai-backbone/vault-sweep.sh" --periodic "$root" 2>&1) || true
    [ -z "$out" ] || { echo "second periodic said: $out"; return 1; }
    [ ! -e "$place/two/brain/later.md" ] || { echo "a run inside 3 hours copied"; return 1; }
  }
  check "the desk sweep copies every sibling, keeps off off, and waits 3 hours" "vault_sibling_sweep"
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

fi
if lane_wants secrets; then
section "secrets in brain"
# spec 036. Files here are made for the test; a real secret is never opened.
modeof() { perl -e 'printf "%04o\n", (stat($ARGV[0]))[2] & 07777' "$1"; }
check "AGENTS.md says secrets live in brain/secrets/" "grep -q 'brain/secrets/' AGENTS.md && grep -q 'Never print, copy or quote one' AGENTS.md"
# Git Bash on Windows copies the file for `ln -s` unless symbolic links are
# turned on (measured on windows-latest, 2026-10-21): no link, nothing moves.
rm -f "$tmp/lp-target" "$tmp/lp"; : > "$tmp/lp-target"
if ln -s "$tmp/lp-target" "$tmp/lp" 2>/dev/null && [ -L "$tmp/lp" ]; then
  echo k > tracked.p12
  git add -f tracked.p12
  check "secrets-to-brain refuses a file git tracks" "says 'Not moved: tracked.p12 is tracked by git' just secrets-to-brain && [ -f tracked.p12 ] && [ ! -L tracked.p12 ]"
  git rm -fq --cached tracked.p12
  rm -f tracked.p12
  ln -s /no/such/target .env.other
  check "secrets-to-brain refuses a path that is already a link" "says 'Not moved: .env.other is already a link' just secrets-to-brain && [ -L .env.other ]"
  rm -f .env.other
  echo k > wait.key
  mkdir -p brain/secrets
  echo x > brain/secrets/wait.key
  check "secrets-to-brain refuses a target that exists" "says 'Not moved: brain/secrets/wait.key already exists' just secrets-to-brain && [ -f wait.key ] && [ ! -L wait.key ]"
  rm -f wait.key brain/secrets/wait.key
  rmdir brain/secrets 2>/dev/null || true
  mkdir -p a/b ios
  echo A=1 > .env
  echo B=2 > a/b/.env
  echo k > ios/dist.p12
  chmod 0600 .env a/b/.env ios/dist.p12
  rootm=$(modeof .env)
  out=$(just secrets-to-brain 2>&1) || true
  check "secrets-to-brain moves a root .env, a nested .env and a key, and prints each" "grep -qx 'moved .env' <<<\"\$out\" && grep -qx 'moved a/b/.env' <<<\"\$out\" && grep -qx 'moved ios/dist.p12' <<<\"\$out\""
  check "and leaves a relative link at each old path" "[ -L .env ] && [ \"\$(readlink .env)\" = 'brain/secrets/.env' ] && [ -L a/b/.env ] && [ \"\$(readlink a/b/.env)\" = '../../brain/secrets/a/b/.env' ] && [ -L ios/dist.p12 ] && [ \"\$(readlink ios/dist.p12)\" = '../brain/secrets/ios/dist.p12' ]"
  check "and keeps the file's mode" "[ \"\$(modeof brain/secrets/.env)\" = '$rootm' ]"
  check "_secret-files still lists a file that was moved" "says '^\\.env\$' just _secret-files && says '^a/b/.env\$' just _secret-files && says '^ios/dist.p12\$' just _secret-files"
  out2=$(just secrets-to-brain 2>&1) || true
  check "run twice, it changes nothing the second time" "[ -z \"\$out2\" ] && [ -L .env ] && [ -f brain/secrets/.env ]"
  check "a link at the old path is still ignored by git" "git check-ignore -q .env && git check-ignore -q a/b/.env && git check-ignore -q ios/dist.p12"
  echo 'a line' >> README.md
  check "just save never stages a link" "just save 'docs: a line' && ! git ls-files --error-unmatch -- .env >/dev/null 2>&1 && ! git ls-files --error-unmatch -- a/b/.env >/dev/null 2>&1 && ! git ls-files --error-unmatch -- ios/dist.p12 >/dev/null 2>&1"
  check "doctor does not warn about a key that is a link into brain/secrets/" "! says 'dist.p12' vc repo_doctor"
  rm -f brain/secrets/ios/dist.p12
  check "doctor warns about a link whose file is missing" "says '^  warn  .*(link whose file is missing|bağlantının dosyası yok).*: ios/dist.p12\$' vc repo_doctor"
  echo k > brain/secrets/ios/dist.p12
  chmod 0600 brain/secrets/ios/dist.p12 2>/dev/null || true
  if command -v rsync >/dev/null 2>&1; then
    echo C=3 > .env.stay
    vc just _vault-copy >/dev/null 2>&1
    check "the copy holds a moved secret as a file in brain/secrets/" "[ -f '$copy/brain/secrets/.env' ] && [ ! -L '$copy/brain/secrets/.env' ] && [ -f '$copy/brain/secrets/a/b/.env' ] && [ ! -L '$copy/brain/secrets/a/b/.env' ]"
    check "and a secret still outside brain/ is still copied to secrets/" "[ -f '$copy/secrets/.env.stay' ]"
    check "and a moved secret is not copied again to secrets/" "[ ! -e '$copy/secrets/a/b/.env' ]"
    check "and about-this-copy.txt says secrets live in brain/secrets/" "grep -q 'Secrets live in brain/secrets/' '$copy/about-this-copy.txt' && grep -q 'no longer written' '$copy/about-this-copy.txt'"
    rm -f .env.stay
  fi
  just secrets-back >/dev/null 2>&1
  check "secrets-back puts each file back and removes the link" "[ -f .env ] && [ ! -L .env ] && [ -f a/b/.env ] && [ ! -L a/b/.env ] && [ -f ios/dist.p12 ] && [ ! -L ios/dist.p12 ]"
  check "and leaves brain/secrets/ empty" "[ ! -e brain/secrets ] || [ -z \"\$(find brain/secrets \\( -type f -o -type l \\) 2>/dev/null)\" ]"
  rm -rf a ios .env .env.stay
else
  echo A=1 > .env
  check "without symbolic links, secrets-to-brain moves nothing and says why" "says 'makes no symbolic links' just secrets-to-brain && [ -f .env ] && [ ! -L .env ] && [ ! -e brain/secrets/.env ]"
  rm -f .env
fi
rm -f "$tmp/lp-target" "$tmp/lp"

# spec 041. A directory stands in for the keychain. security, secret-tool,
# powershell.exe and ssh-add on PATH exit 99 if a recipe calls them. Nothing
# here reads this machine's keychain, secret files, or ~/.ssh.
fi
if lane_wants keystore; then
section "secrets in the os keystore (spec 041)"
ks041_note() { ks041_bad=1; ks041_notes="${ks041_notes:-}$1"$'\n'; }
# Git Bash copies a file for ln -s unless this is set and the account may
# create a native link (spec 020, measured 2026-10-21). nativestrict fails
# instead of copying when it cannot.
ks041_ln() {
  local target=$1 link=$2
  if command -v cygpath >/dev/null 2>&1; then
    # A native Windows link whose target is /d/... does not resolve; git.exe
    # and Perl then treat the link and its target as two files (spec 041).
    case "$target" in
      /*|[A-Za-z]:*) target=$(cygpath -m "$target") ;;
    esac
    ( export MSYS=winsymlinks:nativestrict; ln -s "$target" "$link" )
  else
    ln -s "$target" "$link"
  fi
}
# chmod 555 does not stop MSYS rm: it clears the read-only bit and deletes.
# A delete-child deny is what makes the rollback's rm fail (spec 041).
ks041_lock_dir() {
  local dir=$1
  chmod 555 "$dir" 2>/dev/null || true
  if command -v cygpath >/dev/null 2>&1 && command -v icacls >/dev/null 2>&1; then
    icacls "$(cygpath -w "$dir")" /deny '*S-1-1-0:(DC)' >/dev/null 2>&1 || true
    if [ -f "$dir/config.env" ]; then
      icacls "$(cygpath -w "$dir/config.env")" /deny '*S-1-1-0:(D)' >/dev/null 2>&1 || true
      # icacls deny is not enough: MSYS rm still deletes. A process holding
      # the file open is what makes the rollback's rm fail (spec 041).
      "$py" -c "import sys,time; f=open(sys.argv[1],'rb'); time.sleep(120)" "$(cygpath -w "$dir/config.env")" &
      printf '%s\n' "$!" > "$tmp/ks041-hold-pid"
    fi
  fi
}
ks041_unlock_dir() {
  local dir=$1 pid
  if [ -f "$tmp/ks041-hold-pid" ]; then
    pid=$(cat "$tmp/ks041-hold-pid" 2>/dev/null || true)
    if [ -n "$pid" ]; then suite_stop "$pid"; fi
    rm -f "$tmp/ks041-hold-pid"
  fi
  if command -v cygpath >/dev/null 2>&1 && command -v icacls >/dev/null 2>&1; then
    icacls "$(cygpath -w "$dir")" /remove:d '*S-1-1-0' >/dev/null 2>&1 || true
    if [ -f "$dir/config.env" ]; then
      icacls "$(cygpath -w "$dir/config.env")" /remove:d '*S-1-1-0' >/dev/null 2>&1 || true
    fi
  fi
  chmod 755 "$dir" 2>/dev/null || true
}
ks041_links_ok() {
  local t="$tmp/ks041-probe-t" l="$tmp/ks041-probe-l" rc=0
  rm -f "$t" "$l"
  : > "$t"
  ks041_ln "$t" "$l" || true
  if [ ! -L "$l" ]; then rc=1; fi
  rm -f "$t" "$l"
  return "$rc"
}
# The kind is an argument, and the format does not start with a dash: bash
# printf would read that as an option, and a PEM header on one line is a
# private key to the hook (spec 041).
ks041_pem_begin() { printf '%s\n' "-----BEGIN $1-----"; }
ks041_pem_end() { printf '%s\n' "-----END $1-----"; }
ks041_main() {
  local ks="$tmp/ks041" kstore="$tmp/ks041-store" khome="$tmp/ks041-home"
  local kbin="$tmp/ks041-bin" kout="$tmp/ks041-out" kcalled="$tmp/ks041-called"
  local fix="$tmp/ks041-fix" folder out out2
  ks041_bad=0
  rm -rf "$ks" "$kstore" "$khome" "$kbin" "$kout" "$fix"
  mkdir -p "$kstore/items" "$kstore/reason" "$khome/.ssh" "$kbin" "$kout" "$fix"
  : > "$kcalled"
  cat > "$kbin/security" << 'EOF'
#!/bin/sh
printf '%s\n' "$0" >> "${KS_CALLED:-/dev/null}"
exit 99
EOF
  cp "$kbin/security" "$kbin/secret-tool"
  cp "$kbin/security" "$kbin/ssh-add"
  cp "$kbin/security" "$kbin/powershell.exe"
  cat > "$kbin/take" << 'EOF'
#!/bin/sh
out=${KS_TAKE_OUT:?}
mkdir -p "$out"
: > "$out/ran"
printf '%s\n' "$@" > "$out/argv"
env > "$out/env"
cat > "$out/stdin"
EOF
  chmod +x "$kbin/security" "$kbin/secret-tool" "$kbin/ssh-add" "$kbin/powershell.exe" "$kbin/take"
  if ! ( cd "$root" && just new-project "$ks" en ) >"$tmp/ks041-new.txt" 2>&1; then
    printf '%s\n' "new-project failed" >&2
    tail -n 30 "$tmp/ks041-new.txt" >&2
    return 1
  fi
  folder=$(basename "$ks")
  printf '%s\n' 'ks041-fixture-value' > "$fix/token"
  printf '%s\n' 'ks041-other-bytes' > "$fix/other"
  printf '%s\n' 'ks041-hosts' > "$fix/hosts"
  printf '%s\n' 'ks041-aws' > "$fix/aws"
  printf '%s\n' 'ks041-asc' > "$fix/asc"
  mkdir -p "$ks/a/b" "$ks/brain/secrets/.config/gh" "$ks/brain/03-stack/.aws" "$ks/node_modules" "$ks/ios" \
    "$khome/.grok" "$khome/.aws" "$khome/.appstoreconnect" "$khome/.config/gh"
  cp "$fix/token" "$ks/brain/secrets/.env"
  ks041_ln brain/secrets/.env "$ks/.env"
  cp "$fix/token" "$ks/a/b/.env"
  printf '%s\n' 'example' > "$ks/.env.example"
  cp "$fix/token" "$ks/node_modules/.env"
  printf '%s\n' 'notes' > "$ks/brain/03-stack/notes.txt"
  cp "$fix/token" "$ks/brain/03-stack/.env"
  cp "$fix/token" "$ks/brain/03-stack/.aws/credentials"
  cp "$fix/token" "$ks/.envrc"
  printf '%s\n' 'stay' > "$ks/ios/dist.p12"
  cp "$fix/hosts" "$ks/brain/secrets/.config/gh/hosts.yml"
  ks041_ln "$ks/brain/secrets/.config/gh/hosts.yml" "$khome/.config/gh/hosts.yml"
  cp "$fix/token" "$khome/.grok/auth.json"
  cp "$fix/aws" "$khome/.aws/credentials"
  cp "$fix/asc" "$khome/.appstoreconnect/config.env"
  ks041_lock_dir "$khome/.appstoreconnect"
  env AI_BACKBONE_KEYSTORE="$kstore" bash "$root/.ai-backbone/keystore.sh" put "$folder/.envrc" < "$fix/other" >/dev/null
  mkdir -p "$kstore/reason/home/.aws"
  printf 'locked' > "$kstore/reason/home/.aws/credentials"
  { ks041_pem_begin "RSA PRIVATE KEY"; printf '%s\n' 'clear'; ks041_pem_end "RSA PRIVATE KEY"; } > "$khome/.ssh/id_clear"
  { ks041_pem_begin "RSA PRIVATE KEY"; printf '%s\n' 'Proc-Type: 4,ENCRYPTED' 'DEK-Info: AES-128-CBC,00' '' 'cipher'; ks041_pem_end "RSA PRIVATE KEY"; } > "$khome/.ssh/id_enc"
  { ks041_pem_begin "RSA PRIVATE KEY"; printf '%s\n' 'pub'; ks041_pem_end "RSA PRIVATE KEY"; } > "$khome/.ssh/id_clear.pub"
  printf '%s\n' 'UseKeychain no' > "$khome/.ssh/config"
  ks_just() {
    env AI_BACKBONE_KEYSTORE="$kstore" AI_BACKBONE_SECRET_HOME="$khome" \
      AI_BACKBONE_OS=darwin PATH="$kbin:$PATH" KS_CALLED="$kcalled" KS_TAKE_OUT="$kout" \
      just -f "$ks/Justfile" -d "$ks" "$@"
  }
  out=$(ks_just doctor 2>&1) || true
  grep -q 'a/b/.env' <<<"$out" || ks041_note "doctor missed a/b/.env before the move"
  grep -qF '~/.grok/auth.json' <<<"$out" || ks041_note "doctor missed ~/.grok/auth.json before the move"
  out=$(ks_just secrets-to-keystore 2>&1) || true
  grep -qF 'ks041-fixture-value' <<<"$out" && ks041_note "migrate printed a secret"
  grep -qx 'moved .env' <<<"$out" || ks041_note "did not move .env"
  grep -qx 'moved a/b/.env' <<<"$out" || ks041_note "did not move a/b/.env"
  grep -qx 'moved brain/03-stack/.env' <<<"$out" || ks041_note "did not move brain/03-stack/.env"
  grep -qx 'moved brain/03-stack/.aws/credentials' <<<"$out" || ks041_note "did not move stack aws"
  grep -qx 'moved ~/.grok/auth.json' <<<"$out" || ks041_note "did not move grok auth"
  grep -qx 'moved ~/.config/gh/hosts.yml' <<<"$out" || ks041_note "did not move hosts.yml"
  grep -qx "refused: $folder/.envrc already holds different bytes" <<<"$out" || ks041_note "did not refuse .envrc"
  grep -qx 'not moved: ~/.aws/credentials' <<<"$out" || ks041_note "locked aws was not left"
  grep -qx 'not moved: ~/.appstoreconnect/config.env' <<<"$out" || ks041_note "unwritable file was not rolled back"
  grep -qx 'ssh key without a passphrase: ~/.ssh/id_clear' <<<"$out" || ks041_note "clear ssh key was not reported"
  grep -q 'id_enc' <<<"$out" && ks041_note "an encrypted ssh key was reported"
  grep -q 'id_clear.pub' <<<"$out" && ks041_note "a public key was reported"
  [ ! -e "$ks/.env" ] && [ ! -L "$ks/.env" ] || ks041_note ".env link stayed"
  [ ! -e "$ks/brain/secrets/.env" ] || ks041_note "brain/secrets/.env stayed"
  [ ! -e "$ks/a/b/.env" ] || ks041_note "a/b/.env stayed"
  [ ! -e "$ks/brain/03-stack/.env" ] || ks041_note "stack .env stayed"
  [ ! -e "$ks/brain/03-stack/.aws/credentials" ] || ks041_note "stack aws stayed"
  [ -f "$ks/.env.example" ] || ks041_note ".env.example was moved"
  [ -f "$ks/node_modules/.env" ] || ks041_note "node_modules/.env was moved"
  [ -f "$ks/brain/03-stack/notes.txt" ] || ks041_note "notes.txt was moved"
  [ -f "$ks/ios/dist.p12" ] || ks041_note "a certificate was moved"
  [ -f "$ks/.envrc" ] || ks041_note "refused .envrc was removed"
  cmp -s "$fix/token" "$kstore/items/$folder/.env" || ks041_note "stored .env bytes differ"
  cmp -s "$fix/token" "$kstore/items/$folder/a/b/.env" || ks041_note "stored a/b/.env bytes differ"
  [ ! -e "$kstore/items/$folder/brain/secrets/.env" ] || ks041_note "the link and its target became two accounts"
  cmp -s "$fix/other" "$kstore/items/$folder/.envrc" || ks041_note "refused account was overwritten"
  cmp -s "$fix/hosts" "$kstore/items/home/.config/gh/hosts.yml" || ks041_note "hosts.yml account is not the home path"
  [ ! -e "$kstore/items/$folder/brain/secrets/.config/gh/hosts.yml" ] || ks041_note "hosts.yml was stored twice"
  [ ! -e "$khome/.config/gh/hosts.yml" ] && [ ! -L "$khome/.config/gh/hosts.yml" ] || ks041_note "hosts.yml link stayed"
  [ ! -e "$ks/brain/secrets/.config/gh/hosts.yml" ] || ks041_note "hosts.yml target stayed"
  [ ! -e "$khome/.grok/auth.json" ] || ks041_note "grok auth stayed"
  cmp -s "$fix/token" "$kstore/items/home/.grok/auth.json" || ks041_note "grok auth bytes differ"
  [ -f "$khome/.aws/credentials" ] || ks041_note "locked aws file was removed"
  [ ! -e "$kstore/items/home/.aws/credentials" ] || ks041_note "locked aws was stored"
  [ -f "$khome/.appstoreconnect/config.env" ] || ks041_note "rollback removed the file"
  [ ! -e "$kstore/items/home/.appstoreconnect/config.env" ] || ks041_note "rollback left a store copy"
  [ -f "$khome/.ssh/id_clear" ] && [ -f "$khome/.ssh/id_enc" ] || ks041_note "an ssh key was removed"
  [ ! -e "$kstore/items/home/.ssh" ] || ks041_note "an ssh key was stored"
  grep -qx 'UseKeychain no' "$khome/.ssh/config" || ks041_note "an existing UseKeychain no was replaced"
  [ "$(grep -c '^UseKeychain yes$' "$khome/.ssh/config")" = 0 ] || ks041_note "UseKeychain yes was added beside no"
  [ "$(grep -c '^AddKeysToAgent yes$' "$khome/.ssh/config")" = 1 ] || ks041_note "AddKeysToAgent yes was not added once"
  [ ! -s "$kcalled" ] || ks041_note "a keystore command or ssh-add was executed"
  out2=$(ks_just secrets-to-keystore 2>&1) || true
  grep -qE '^moved ' <<<"$out2" && ks041_note "the second run moved something"
  [ "$(grep -c '^AddKeysToAgent yes$' "$khome/.ssh/config")" = 1 ] || ks041_note "the second run duplicated AddKeysToAgent"
  [ "$(grep -c '^UseKeychain no$' "$khome/.ssh/config")" = 1 ] || ks041_note "the second run duplicated UseKeychain"
  ks041_unlock_dir "$khome/.appstoreconnect"
  out=$(ks_just doctor 2>&1) || true
  grep -q 'a/b/.env' <<<"$out" && ks041_note "doctor still names a/b/.env"
  grep -qF '~/.grok/auth.json' <<<"$out" && ks041_note "doctor still names grok auth"
  grep -qF '~/.aws/credentials' <<<"$out" || ks041_note "doctor is quiet about the locked file"
  grep -qF '.envrc' <<<"$out" || ks041_note "doctor is quiet about the refused file"
  rm -rf "$kout"
  out=$(ks_just with-secret "$folder/a/b/.env" -- "$kbin/take" 2>&1) || ks041_note "with-secret failed"
  [ -z "$out" ] || ks041_note "with-secret printed: $out"
  cmp -s "$fix/token" "$kout/stdin" || ks041_note "the command did not receive the secret on stdin"
  grep -qF 'ks041-fixture-value' "$kout/argv" && ks041_note "the secret was an argument"
  grep -qF 'ks041-fixture-value' "$kout/env" && ks041_note "the secret was in the environment"
  if grep -qF -r -- 'ks041-fixture-value' "$tmp/T" 2>/dev/null; then ks041_note "the secret was left in a temp file"; fi
  rm -rf "$kout"
  out=$(ks_just with-secret "$folder/missing" -- "$kbin/take" 2>&1) || true
  [ "$out" = "$folder/missing: absent" ] || ks041_note "absent line was: $out"
  [ ! -e "$kout/ran" ] || ks041_note "an absent account still ran the command"
  mkdir -p "$kstore/reason/$folder"
  printf 'locked' > "$kstore/reason/$folder/locked-one"
  out=$(ks_just with-secret "$folder/locked-one" -- "$kbin/take" 2>&1) || true
  [ "$out" = "$folder/locked-one: locked" ] || ks041_note "locked line was: $out"
  [ ! -e "$kout/ran" ] || ks041_note "a locked account still ran the command"
  printf 'nobody' > "$kstore/reason/$folder/nobody-one"
  out=$(ks_just with-secret "$folder/nobody-one" -- "$kbin/take" 2>&1) || true
  [ "$out" = "$folder/nobody-one: nobody there to approve" ] || ks041_note "nobody line was: $out"
  [ ! -e "$kout/ran" ] || ks041_note "a missing approval still ran the command"
  out=$(ks_just with-secret "$folder/a/b/.env" 2>&1) || true
  [ "$out" = "$folder/a/b/.env: no command" ] || ks041_note "no-command line was: $out"
  ks041_unlock_dir "$khome/.appstoreconnect"
  if [ "$ks041_bad" -ne 0 ]; then
    printf '%s' "${ks041_notes:-}" >&2
  fi
  [ "$ks041_bad" -eq 0 ]
}
ks041_windows() {
  local wbin="$tmp/ks041-wbin" wapp="$tmp/ks041-local" wmark="$tmp/ks041-wmark"
  local wstore="$tmp/ks041-wstore" fix="$tmp/ks041-wfix" got="$tmp/ks041-wgot" whome="$tmp/ks041-whome"
  rm -rf "$wbin" "$wapp" "$wmark" "$wstore" "$whome" "$fix" "$got"
  mkdir -p "$wbin" "$wmark" "$wstore/items" "$wstore/reason" "$whome"
  printf '%s\n' 'ks041-fixture-value' > "$fix"
  cat > "$wbin/powershell.exe" << 'EOF'
#!/bin/sh
cmd=
prev=
for arg in "$@"; do
  if [ "$prev" = "-Command" ]; then cmd=$arg; fi
  prev=$arg
done
case "$cmd" in
  *Unprotect*)
    cat -- "$KS_PATH"
    : > "${KS_WIN_MARK}/unprotect"
    ;;
  *Protect*)
    mkdir -p "$(dirname -- "$KS_PATH")"
    cat > "$KS_PATH"
    : > "${KS_WIN_MARK}/protect"
    ;;
  *) exit 99 ;;
esac
EOF
  cat > "$wbin/security" << 'EOF'
#!/bin/sh
: > "${KS_WIN_MARK}/security"
exit 99
EOF
  cp "$wbin/security" "$wbin/secret-tool"
  chmod +x "$wbin/powershell.exe" "$wbin/security" "$wbin/secret-tool"
  if ! env AI_BACKBONE_KEYSTORE="$wstore" AI_BACKBONE_OS=windows PATH="$wbin:$PATH" KS_WIN_MARK="$wmark" \
      bash "$root/.ai-backbone/keystore.sh" put "win/gated" < "$fix"; then
    printf '%s\n' "a set keystore still failed on the windows branch" >&2
    return 1
  fi
  if [ -e "$wmark/security" ] || [ -e "$wmark/protect" ]; then
    printf '%s\n' "a set keystore executed powershell or security" >&2
    return 1
  fi
  rm -f "$wmark/protect" "$wmark/security" "$wmark/unprotect"
  if ! env -u AI_BACKBONE_KEYSTORE AI_BACKBONE_OS=windows LOCALAPPDATA="$wapp" HOME="$whome" \
      PATH="$wbin:$PATH" KS_WIN_MARK="$wmark" \
      bash "$root/.ai-backbone/keystore.sh" put "win/demo" < "$fix"; then
    printf '%s\n' "windows put failed" >&2
    return 1
  fi
  [ -e "$wmark/protect" ] || { printf '%s\n' "Protect was not called" >&2; return 1; }
  [ ! -e "$wmark/security" ] || { printf '%s\n' "security was called on the windows branch" >&2; return 1; }
  env -u AI_BACKBONE_KEYSTORE AI_BACKBONE_OS=windows LOCALAPPDATA="$wapp" HOME="$whome" \
    PATH="$wbin:$PATH" KS_WIN_MARK="$wmark" \
    bash "$root/.ai-backbone/keystore.sh" get "win/demo" > "$got" || { printf '%s\n' "windows get failed" >&2; return 1; }
  cmp -s "$fix" "$got" || { printf '%s\n' "windows round trip changed the bytes" >&2; return 1; }
  [ -e "$wmark/unprotect" ] || { printf '%s\n' "Unprotect was not called" >&2; return 1; }
}
ks041_ssh_linux() {
  local home="$tmp/ks041-linhome" bare="$tmp/ks041-bare" store="$tmp/ks041-linstore" out
  rm -rf "$home" "$bare" "$store"
  mkdir -p "$home/.ssh" "$bare" "$store/items" "$store/reason"
  { ks041_pem_begin "RSA PRIVATE KEY"; printf '%s\n' 'clear'; ks041_pem_end "RSA PRIVATE KEY"; } > "$home/.ssh/id_clear"
  out=$(cd "$bare" && env AI_BACKBONE_KEYSTORE="$store" AI_BACKBONE_SECRET_HOME="$home" AI_BACKBONE_OS=linux \
    bash "$root/.ai-backbone/keystore.sh" migrate) || true
  grep -qx 'ssh key without a passphrase: ~/.ssh/id_clear' <<<"$out" || { printf '%s\n' "linux did not report the clear key" "$out" >&2; return 1; }
  [ ! -e "$home/.ssh/config" ] || { printf '%s\n' "linux wrote Apple ssh config" >&2; return 1; }
  [ -f "$home/.ssh/id_clear" ] || { printf '%s\n' "linux removed the key" >&2; return 1; }
}
ks041_budget() {
  local f="$tmp/ks041-settings.json" badf="$tmp/ks041-bad.json" before
  "$py" -c 'import json,sys; json.dump({"kept": True, "permissions": {"deny": ["Bash(sudo:*)"]}}, open(sys.argv[1],"w"))' "$f" || return 1
  "$py" "$root/.ai-backbone/budget.py" secrets "$f" >/dev/null || return 1
  "$py" "$root/.ai-backbone/budget.py" secrets "$f" >/dev/null || return 1
  "$py" -c '
import json, sys
p = sys.argv[1]
d = json.load(open(p))
deny = d["permissions"]["deny"]
need = [
    "Bash(sudo:*)",
    "Bash(security find-generic-password:*)",
    "Bash(secret-tool lookup:*)",
    "Bash(just with-secret:*)",
    "Bash(ssh-add:*)",
    "Bash(/usr/bin/ssh-add:*)",
    "Read(**/.env)",
    "Read(**/.envrc)",
    "Read(**/ssh-agent.sock)",
    "Read(**/ai-backbone/keystore/**)",
]
for n in need:
    if deny.count(n) != 1:
        sys.exit("count " + n + " " + str(deny.count(n)))
if "Read(**/.env.example)" in deny:
    sys.exit("example")
blob = open(p).read()
if "/Users/" in blob or "home/" in blob:
    sys.exit("named home")
if d.get("kept") is not True:
    sys.exit("kept")
' "$f" || return 1
  printf '{\n' > "$badf"
  before=$(cksum "$badf")
  "$py" "$root/.ai-backbone/budget.py" secrets "$badf" >/dev/null 2>&1 || true
  [ "$(cksum "$badf")" = "$before" ] || { printf '%s\n' "broken json was rewritten" >&2; return 1; }
}
if ks041_links_ok; then
  check "token files move into the fake keystore, a different value is refused, and the reader uses stdin only" "ks041_main"
else
  echo "skipped on Windows: ln -s did not make a symbolic link, so a link and its target cannot stay one account (spec 041)"
  ok "token files move into the fake keystore, a different value is refused, and the reader uses stdin only"
fi
check "the windows branch uses the fake DPAPI path and a set keystore calls neither powershell nor security" "ks041_windows"
check "linux reports a clear ssh key and writes no Apple config" "ks041_ssh_linux"
check "budget.py secrets merges the keystore denies once and leaves broken json alone" "ks041_budget"
check "keystore.sh does not name /usr/bin/security" "! grep -qF '/usr/bin/security' '$root/.ai-backbone/keystore.sh'"
check "the night skip and the CI rule are in the spec skill and how-it-works" "grep -q 'A night step that needs a secret is skipped and named in the morning' '$root/.agents/skills/spec/SKILL.md' && grep -q 'CI does not call the reader' '$root/.agents/skills/spec/SKILL.md' && grep -q 'A night step that needs a secret is skipped and named in the morning' '$root/docs/how-it-works.md' && grep -q 'CI does not call the reader' '$root/docs/how-it-works.md'"
check "spec 036 points at spec 041" "grep -q 'spec 041' '$root/docs/specs/036-secrets-in-brain.md'"

# A save must never commit code the language layer rejects (3.7.0).
fi
if lane_wants lint; then
section "lint before save"
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
# The routine moves the scanner in the backbone's own config (spec 021); a
# project gets the seed's, so the two, and the backbone's own watch row, move
# together or the suite says which one stayed behind.
check "the seed's scanner is the backbone's own, and its watch row says so ($seedrev)" "[ '$seedrev' = '$hookrev' ] && grep -qx 'pin = \"$hookrev\"' '$root/docs/upstream.toml'"
# A monorepo tags its sub-packages by path; the 2 in `h2tools` was read as a version
# and called newer than v0.9 every week.
check "a monorepo tag is not newer than the pin"        "\"\$(just _py)\" -c 'import importlib.util as i; s=i.spec_from_file_location(\"u\", \".ai-backbone/upstream.py\"); u=i.module_from_spec(s); s.loader.exec_module(u); raise SystemExit(0 if u.parts(\"python/h2tools-core/v0.1.1\") < u.parts(\"v0.9\") < u.parts(\"v1.0\") else 1)'"
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
# n-259b1e: Zed opened basedpyright and ruff on this file. Each finding was
# fixed where it was, never hidden: a blanket noqa or ignore would hide the
# next one. The two type errors were a TextIO without reconfigure and an
# extractfile member that may be None. ruff reads the whole file where it is
# installed; the suite's runners have no ruff, so the named patterns are also
# checked here with the Python every runner has.
cat > "$tmp/diag259.py" <<'PY'
import ast
import re
import sys

path = sys.argv[1]
text = open(path, encoding="utf-8").read()
bad = []
for n, line in enumerate(text.splitlines(), 1):
    if re.search(r"#\s*(ruff:\s*noqa|noqa\s*$|type:\s*ignore\s*$)", line):
        bad.append(f"{n}: a blanket ignore")
    if "datetime.timezone.utc" in line:
        bad.append(f"{n}: datetime.timezone.utc")
    if re.search(r"startswith\([\"']\./[\"']\)", line) and "[2:]" in line:
        bad.append(f"{n}: a prefix taken with a slice")
    if re.search(r"extractfile\([^)]*\)\.read\(", line):
        bad.append(f"{n}: an extractfile member read without a None check")
if not re.search(r"if isinstance\([^\n]+, io\.TextIOWrapper\):\n\s+[^\n]*\.reconfigure\(", text):
    bad.append("reconfigure is not behind its TextIOWrapper check")
tree = ast.parse(text)
for node in ast.walk(tree):
    if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute):
        run = (isinstance(node.func.value, ast.Name) and node.func.value.id == "subprocess"
               and node.func.attr == "run")
        if run and not any(k.arg == "check" for k in node.keywords):
            bad.append(f"{node.lineno}: subprocess.run without check=")
    if isinstance(node, ast.JoinedStr):
        for value in node.values:
            if (isinstance(value, ast.FormattedValue) and isinstance(value.value, ast.Call)
                    and isinstance(value.value.func, ast.Name) and value.value.func.id == "str"):
                bad.append(f"{node.lineno}: str() inside an f-string")
if bad:
    print("\n".join(bad))
    raise SystemExit(1)
PY
check "upstream.py has none of the editor findings n-259b1e named, and no blanket ignore" "\"\$py\" '$tmp/diag259.py' '$root/.ai-backbone/upstream.py'"
if command -v ruff >/dev/null 2>&1; then
  check "and ruff reads it clean" "ruff check --isolated '$root/.ai-backbone/upstream.py'"
fi
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
# The machine's own gitconfig is included for the commits above, and on a cloud
# agent it rewrites https://github.com/ to a token URL. That rewrite wins over
# the file URL this check plants, so these two calls read no other gitconfig.
: > "$tmp/gitconfig-empty"
sandbox() { hostile env -u AI_BACKBONE_OFFLINE https_proxy=$dead http_proxy=$dead no_proxy= PATH="$gitbin:/usr/bin:/bin" GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="$tmp/gitconfig-empty" GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0="url.$(fileurl "$1")/.insteadOf" GIT_CONFIG_VALUE_0="https://github.com/"; }
check "when the GitHub API refuses, the tags are asked of git" "says '^  tool +1\\.2\\.0 .* v1\\.10\\.0 +1 newer' sandbox '$tmp/tags'"
# The line above stored a successful read of github:a/b. A shared copy under a
# day old is that answer, so a missing folder would never be asked. This check
# is the ask itself failing, and it uses an empty cache.
# The FAIL names what was seen: on a runner nobody can run the line by hand.
mkdir -p "$tmp/upstream-cache-miss"
saw_full=$(AI_BACKBONE_UPSTREAM_CACHE="$tmp/upstream-cache-miss" sandbox "$tmp/no-such-folder" 2>&1)
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
ask() { ( cd "$tmp/hostile" && env -u AI_BACKBONE_OFFLINE https_proxy=$dead http_proxy=$dead no_proxy= PATH="$tmp/sdk/bin:$tmp/brew/bin:$gitbin:/usr/bin:/bin" GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="$tmp/gitconfig-empty" GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0="url.$(fileurl "$tmp/tags")/.insteadOf" GIT_CONFIG_VALUE_0="https://github.com/" "$py" "$root/.ai-backbone/upstream.py" "$@" ); }
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
check "a channel that is not there is said, with the ones that are" "says '^  typo: .*stabel.* beta, stable' fl && says '^  kind: unknown source .* flutter:stable, hf:owner/name, ghcommit:owner/repo, brew:name, pointer:url' fl"
check "the template names Flutter's own source"           "grep -q 'flutter:stable' '$root/.ai-backbone/templates/upstream.toml'"
# pin_is_real asked whether the file held the pin anywhere in its text, so a file
# that had moved on to 1.38.20 still "held" 1.38.2 and MOVED was never said. And
# a pin written with its label (rust-v0.155.0) is held by a file that says 0.155.0.
# A pin written with a v, as the source tags it, is held by an image tag that
# writes the bare number (spec 026), and a row with a tag pattern keeps the
# pin the file writes.
printf 'near: 1.38.20\nimage: example/example:v3.2.4-alpine\ncodex = "0.155.0"\nproxy: example/proxy:2.11.4-alpine\ndb: postgres:18.6-trixie\nuses: actions/checkout@v8\ncap: 7\n' > "$tmp/hostile/docs/held.txt"
printf '[[watch]]\nname = "near"\nsource = "pub:near"\npin = "1.38.2"\npinned_in = "docs/held.txt"\n\n[[watch]]\nname = "image"\nsource = "github:a/b"\npin = "3.2.4"\npinned_in = "docs/held.txt"\n\n[[watch]]\nname = "codex"\nsource = "github:a/b"\npin = "rust-v0.155.0"\npinned_in = "docs/held.txt"\n\n[[watch]]\nname = "proxy"\nsource = "github:a/b"\npin = "v2.11.4"\npinned_in = "docs/held.txt"\n\n[[watch]]\nname = "gone"\nsource = "github:a/b"\npin = "v2.11.5"\npinned_in = "docs/held.txt"\n\n[[watch]]\nname = "pg"\nsource = "github:a/b"\npin = "18.6"\ntag = "REL_{major}_{minor}"\npinned_in = "docs/held.txt"\n\n[[watch]]\nname = "checkout"\nsource = "github:a/b"\npin = "v7"\nmajor = true\npinned_in = "docs/held.txt"\n' > "$tmp/hostile/docs/upstream.toml"
# PyPI, where uv installs from (spec 021): a release is dated by its first file,
# one with no files or only yanked files is not a release, and 1.2.0rc1 is a
# prerelease. From a fixture, with every other address refused.
pypi() { "$py" -c "import importlib.util as i, json, sys; s=i.spec_from_file_location('u', '$rootw/.ai-backbone/upstream.py'); u=i.module_from_spec(s); s.loader.exec_module(u); u.fetch_json=lambda url, headers=None: json.load(open('$rootw/.ai-backbone/fixtures/pypi-releases.json')) if url == 'https://pypi.org/pypi/tool/json' else sys.exit('asked ' + url); r=u.from_pypi('tool'); print(' '.join(x['version'] + '@' + x['at'] + ('~pre' if x['prerelease'] else '') for x in r)); print('newer', ' '.join(x['version'] for x in u.newer_than('1.0.0', r, False)))"; }
check "a PyPI release is dated by its first file, and a yanked or empty one is no release" "[ \"\$(pypi | head -1)\" = '1.2.0rc1@2026-04-01~pre 1.1.0@2026-03-01 1.0.0@2026-01-10 0.9.0@2025-12-01' ]"
check "and what is newer than a pin leaves its release candidates out" "[ \"\$(pypi | tail -1)\" = 'newer 1.1.0' ]"
check "a major pin takes its own minors: only a new major is newer" "upy '[r[\"version\"] for r in u.new_majors(\"v7\", [{\"version\": v} for v in (\"v7.0.1\", \"v8\", \"v8.1.0\")])] == [\"v8\", \"v8.1.0\"]'"
check "a pin that is only the start of a longer version is MOVED" "says '^  near .* MOVED\$' hostile env && says '^  image .* ok\$' hostile env && says '^  codex .* ok\$' hostile env"
check "a pin written v2.11.4 is held by an image tag of 2.11.4, and v2.11.5 is not" "says '^  proxy .* ok\$' hostile env && says '^  gone .* MOVED\$' hostile env && says '^  pg .* ok\$' hostile env"
check "but a major pin v7 is not held by a lone 7 once the file says v8" "says '^  checkout .* MOVED\$' hostile env"
check "a tag pattern no tag fits says so, with the pattern" "says 'looks like tag = .REL_[{]major[}]_[{]minor[}].' \"\$(just _py)\" -c 'import importlib.util as i; s=i.spec_from_file_location(\"u\", \".ai-backbone/upstream.py\"); u=i.module_from_spec(s); s.loader.exec_module(u); u.tagged({\"tag\": \"REL_{major}_{minor}\"}, [{\"version\": \"v18.6\", \"prerelease\": False}])'"
# A major written alone is current when any release of that major is listed;
# with no X.0.0 in the window it read UNKNOWN (spec 026).
check "a major row is answered by any release of its major" "upy 'u.same_major(\"docker-v29\", [{\"version\": v, \"prerelease\": False} for v in (\"api-v1.2.0\", \"docker-v29.4.1\")]) and not u.same_major(\"docker-v29\", [{\"version\": \"docker-v28.5.0\", \"prerelease\": False}])'"
# A source that spells its versions its own way (REL_18_6) is read through the
# row's tag pattern, and a tag of another shape is left out (spec 026).
check "a tag pattern reads REL_18_7 as 18.7, newer than 18.6, and leaves REL9_6_24 out" "upy '[r[\"version\"] for r in u.newer_than(\"18.6\", u.tagged({\"tag\": \"REL_{major}_{minor}\"}, [{\"version\": v, \"prerelease\": False} for v in (\"REL_18_7\", \"REL_18_6\", \"REL9_6_24\")]), False)] == [\"18.7\"] and u.tag_of({\"tag\": \"REL_{major}_{minor}\"}, \"18.6\") == \"REL_18_6\"'"
check "a tag pattern's {even} keeps the stable line and leaves odd minors out" "upy '[r[\"version\"] for r in u.newer_than(\"1.26.3\", u.tagged({\"tag\": \"release-{major}.{even}.{patch}\"}, [{\"version\": v, \"prerelease\": False} for v in (\"release-1.29.1\", \"release-1.28.1\", \"release-1.28.0\", \"release-1.27.4\", \"release-1.26.3\")]), False)] == [\"1.28.1\", \"1.28.0\"] and u.tag_of({\"tag\": \"release-{major}.{even}.{patch}\"}, \"1.28.0\") == \"release-1.28.0\" and [r[\"version\"] for r in u.tagged({\"tag\": \"release-{major}.{odd}.{patch}\"}, [{\"version\": v, \"prerelease\": False} for v in (\"release-1.29.1\", \"release-1.28.0\")])] == [\"1.29.1\"]'"
# n-73d3f2: the pin is the number the file writes (1.30.6), and the tag pattern
# is what turns release-1.31.8 into an odd minor the stable line does not follow.
check "nginx-like tags follow the even minor: 1.31.8 is not newer than 1.30.6, and 1.32.0 is" "upy '[r[\"version\"] for r in u.tagged({\"tag\": \"release-{major}.{even}.{patch}\"}, [{\"version\": v, \"prerelease\": False} for v in (\"release-1.32.0\", \"release-1.31.8\", \"release-1.30.6\")])] == [\"1.32.0\", \"1.30.6\"] and [r[\"version\"] for r in u.newer_than(\"1.30.6\", u.tagged({\"tag\": \"release-{major}.{even}.{patch}\"}, [{\"version\": v, \"prerelease\": False} for v in (\"release-1.32.0\", \"release-1.31.8\", \"release-1.30.6\")]), False)] == [\"1.32.0\"]'"
check "the template says a tag pattern can keep one minor line" "grep -q '{even}' '$root/.ai-backbone/templates/upstream.toml'"
check "a filter keeps one stable line and leaves mainline out" "upy '[r[\"version\"] for r in u.newer_than(\"release-1.30.2\", u.matched({\"filter\": \"release-1\\\\.30\\\\.\"}, [{\"version\": v, \"prerelease\": False} for v in (\"release-1.31.8\", \"release-1.30.4\", \"release-1.30.2\")]), False)] == [\"release-1.30.4\"]'"
check "a filter that matches nothing the source lists says so" "says 'matches filter' \"\$(just _py)\" -c 'import importlib.util as i; s=i.spec_from_file_location(\"u\", \".ai-backbone/upstream.py\"); u=i.module_from_spec(s); s.loader.exec_module(u); u.matched({\"filter\": \"release-1\\\\.30\\\\.\"}, [{\"version\": \"release-1.31.8\"}])'"
check "the upstream template names a filter for one stable line" "grep -q 'follow one stable line' '$root/.ai-backbone/templates/upstream.toml'"
check "the template says where a pub pin lives"            "grep -q 'pubspec.lock for pub' '$root/.ai-backbone/templates/upstream.toml'"
# pub.dev is a source kind, for Dart and Flutter (3.20.0): a `pub:` row is counted
# like any other, not refused as unknown, and its version's folder in the pub cache
# and its documentation are in the where-list.
printf '\n[[watch]]\nname = "flame"\nsource = "pub:flame"\npin = "1.38.2"\n' >> docs/upstream.toml
mkdir -p "$tmp/pub-cache/hosted/pub.dev/flame-1.38.2" && echo x > "$tmp/pub-cache/hosted/pub.dev/flame-1.38.2/CHANGELOG.md"
check "a pub.dev package is watched like the rest"      "says '^  flame: offline' just upstream && ! says 'unknown source' just upstream && says 'docs +https://pub.dev/documentation/flame/1.38.2/\$' just upstream flame && says 'notes +$(winpath "$tmp")/pub-cache/hosted/pub.dev/flame-1.38.2/CHANGELOG.md' env PUB_CACHE='$tmp/pub-cache' just upstream flame"
# spec 035: one answer per source per machine, for a day. Each mode has its own
# folder. fetch_json is replaced before main runs, so nothing here is asked of
# a registry. The recipe check below is the one that goes through `just`.
cat > "$tmp/spec035.py" <<'PY'
import datetime
import importlib.util
import io
import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

root, mode, base = sys.argv[1:]
os.environ["AI_BACKBONE_UPSTREAM_CACHE"] = str(Path(base) / mode)
os.environ.pop("AI_BACKBONE_OFFLINE", None)
if mode == "fresh-slow":
    os.environ["AI_BACKBONE_UPSTREAM_BUDGET"] = "0"
spec = importlib.util.spec_from_file_location("u", str(Path(root) / ".ai-backbone" / "upstream.py"))
u = importlib.util.module_from_spec(spec)
spec.loader.exec_module(u)
u.OFFLINE = False
fixture = {"releases": {
    "1.0.0": [{"upload_time_iso_8601": "2026-01-01T00:00:00Z"}],
    "1.2.0": [{"upload_time_iso_8601": "2026-06-01T00:00:00Z"}],
}}
calls = {"n": 0, "rate": False}

def fake(url, headers=None):
    calls["n"] += 1
    if calls["rate"]:
        raise u.urllib.error.HTTPError(url, 403, "Forbidden", {}, io.BytesIO(b"API rate limit exceeded"))
    if url != "https://pypi.org/pypi/tool/json":
        raise SystemExit("asked " + url)
    return fixture

u.fetch_json = fake

def fail(msg):
    print(msg, file=sys.stderr)
    raise SystemExit(1)

def project(path):
    p = Path(path)
    (p / "docs").mkdir(parents=True, exist_ok=True)
    (p / ".git").mkdir(parents=True, exist_ok=True)
    (p / "docs" / "upstream.toml").write_text(
        '[[watch]]\nname = "tool"\nsource = "pypi:tool"\npin = "1.0.0"\n')
    return p

def run(path, *args):
    os.chdir(path)
    sys.argv = ["upstream.py", *args]
    buf = io.StringIO()
    old = sys.stdout
    sys.stdout = buf
    try:
        rc = u.main()
    finally:
        sys.stdout = old
    return rc, buf.getvalue()

def rewind(hours):
    path = u.share_file("pypi:tool")
    data = json.loads(path.read_text(encoding="utf-8"))
    when = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(hours=hours)
    data["fetched"] = when.replace(microsecond=0).isoformat()
    data["failed_at"] = ""
    data["error"] = ""
    path.write_text(json.dumps(data), encoding="utf-8")

work = Path(base) / (mode + "-work")
one = project(work / "a")

if mode == "age-fresh":
    rc, out = run(one)
    if rc != 0 or calls["n"] != 1 or "1.2.0" not in out:
        fail(f"seed rc={rc} calls={calls['n']}\n{out}")
    rewind(2)
    calls["n"] = 0
    rc, out = run(one)
    if calls["n"] != 0 or "1.2.0" not in out:
        fail(f"fresh copy was asked ({calls['n']})\n{out}")
elif mode == "age-stale":
    run(one)
    rewind(25)
    calls["n"] = 0
    rc, out = run(one)
    if calls["n"] != 1:
        fail(f"a day-old copy was not asked ({calls['n']})\n{out}")
elif mode == "refresh":
    run(one)
    calls["n"] = 0
    rc, out = run(one, "--refresh")
    if rc != 0 or calls["n"] != 1:
        fail(f"--refresh rc={rc} calls={calls['n']}\n{out}")
elif mode == "shared":
    two = project(work / "b")
    rc, out = run(one)
    rc2, out2 = run(two)
    files = [p for p in u.share_root().glob("*.json")]
    if calls["n"] != 1 or len(files) != 1 or "1.2.0" not in out or "1.2.0" not in out2:
        fail(f"shared calls={calls['n']} files={files}\n{out}\n{out2}")
    (two / "docs" / "upstream.toml").write_text(
        '[[watch]]\nname = "other"\nsource = "pypi:other"\npin = "1.0.0"\n')

    def fake_other(url, headers=None):
        calls["n"] += 1
        if url == "https://pypi.org/pypi/other/json":
            return {"releases": {"9.0.0": [{"upload_time_iso_8601": "2026-06-01T00:00:00Z"}]}}
        raise SystemExit("asked " + url)

    u.fetch_json = fake_other
    run(two)
    files = [p for p in u.share_root().glob("*.json")]
    if len(files) != 2:
        fail(f"two sources wrote {len(files)} files")
elif mode == "offline-empty":
    u.OFFLINE = True
    rc, out = run(one)
    if rc != 0 or calls["n"] != 0 or "offline" not in out or "1.2.0" in out:
        fail(f"rc={rc} calls={calls['n']}\n{out}")
elif mode == "offline-stale":
    run(one)
    rewind(30)
    calls["n"] = 0
    u.OFFLINE = True
    rc, out = run(one)
    if rc != 0 or calls["n"] != 0 or "1.2.0" not in out or "offline" not in out or "hours ago" not in out:
        fail(f"rc={rc} calls={calls['n']}\n{out}")
elif mode == "rate":
    run(one)
    rewind(30)
    calls["n"] = 0
    calls["rate"] = True
    rc, out = run(one)
    if calls["n"] != 1 or "1.2.0" not in out or "rate-limited" not in out or "hours ago" not in out:
        fail(f"first calls={calls['n']}\n{out}")
    calls["n"] = 0
    rc, out = run(one)
    if calls["n"] != 0 or "rate-limited" not in out or "1.2.0" not in out:
        fail(f"second calls={calls['n']}\n{out}")
elif mode == "slow":
    run(one)
    rewind(30)
    calls["n"] = 0
    os.chdir(one)
    entry = {"name": "tool", "source": "pypi:tool", "pin": "1.0.0"}
    releases, old, live = u.obtain(entry, False, time.monotonic() - 1)
    if calls["n"] != 0 or old != "slow" or live:
        fail(f"calls={calls['n']} old={old} live={live}")
    if not any(r.get("version") == "1.2.0" for r in releases):
        fail(repr(releases))
    releases, old, live = u.obtain(entry, False, time.monotonic() + 100)
    if calls["n"] != 0 or old != "slow":
        fail(f"retried calls={calls['n']} old={old}")
elif mode == "budget-cap":
    u.CALL_DEADLINE = time.monotonic() + 0.2
    got = u.call_timeout(30)
    if got > 0.25 or got < 0.05:
        fail(f"a call in flight was given {got}s")
    u.CALL_DEADLINE = time.monotonic() - 1
    if abs(u.call_timeout(30) - 0.05) > 0.001:
        fail("past the deadline a call still waited")
elif mode == "fresh":
    rc, out = run(one, "--freshness")
    if rc != 0 or "=== FRESHNESS (checked " not in out or "Behind: tool 1.0.0 → 1.2.0" not in out:
        fail(f"rc={rc}\n{out}")
    if f"Backbone: {u.backbone_version()}" not in out or "First job: update tool (1.0.0 → 1.2.0)" not in out:
        fail(out)
    if "To read: nothing" not in out or "MOVED: nothing" not in out:
        fail(out)
    if "Do it in this session" not in out:
        fail(out)
    behind = [("tool", "1.0.0", "1.2.0")]
    for worker, want in (("grok", "WORKER is grok: hand it over with just delegate"),
                         ("kimi", "WORKER is kimi: hand it over with just delegate"),
                         ("off", "Do it in this session"), ("", "Do it in this session")):
        u.os.environ["WORKER"] = worker
        if want not in u.first_job(behind, [], []):
            fail(f"WORKER={worker!r}: {u.first_job(behind, [], [])}")
    u.os.environ.pop("WORKER", None)
    calls["n"] = 0
    rc, out = run(one, "--freshness")
    if calls["n"] != 0 or "Behind: tool 1.0.0 → 1.2.0" not in out:
        fail(f"second run asked ({calls['n']})\n{out}")
elif mode == "fresh-offline":
    run(one)
    rewind(30)
    calls["n"] = 0
    u.OFFLINE = True
    rc, out = run(one, "--freshness")
    if rc != 0 or calls["n"] != 0 or "1.2.0" not in out or "offline" not in out or "hours ago" not in out:
        fail(f"rc={rc} calls={calls['n']}\n{out}")
    if "Behind: tool 1.0.0 → 1.2.0" not in out:
        fail(out)
elif mode == "fresh-empty":
    u.OFFLINE = True
    rc, out = run(one, "--freshness")
    if rc != 0 or calls["n"] != 0 or "=== FRESHNESS" not in out or "offline" not in out or "1.2.0" in out:
        fail(f"rc={rc} calls={calls['n']}\n{out}")
    if "Could not check:" not in out or "no earlier result" not in out:
        fail(out)
elif mode == "fresh-slow":
    run(one)
    rewind(30)
    calls["n"] = 0
    rc, out = run(one, "--freshness")
    if rc != 0 or calls["n"] != 0 or "slow" not in out or "1.2.0" not in out or "hours ago" not in out:
        fail(f"rc={rc} calls={calls['n']}\n{out}")
elif mode == "fresh-moved":
    (one / "docs" / "held.txt").write_text("version = 0.0.1\n", encoding="utf-8")
    (one / "docs" / "upstream.toml").write_text(
        '[[watch]]\nname = "tool"\nsource = "pypi:tool"\npin = "1.2.0"\npinned_in = "docs/held.txt"\n',
        encoding="utf-8")
    rc, out = run(one, "--freshness")
    if rc != 0 or "MOVED: tool" not in out or "Behind: nothing" not in out:
        fail(f"rc={rc}\n{out}")
    if "First job: fix the pin for tool" not in out:
        fail(out)
elif mode == "fresh-idea":
    (one / "docs" / "upstream.toml").write_text(
        '[[watch]]\nname = "tool"\nsource = "pypi:tool"\npin = "1.2.0"\n\n'
        '[[watch]]\nname = "orch"\nkind = "idea"\nsource = "pypi:tool"\npin = "1.0.0"\n'
        'why = "an idea"\nlook_for = "a board of every running job across projects"\n',
        encoding="utf-8")
    rc, out = run(one, "--freshness")
    if rc != 0 or calls["n"] != 1 or "Behind: nothing" not in out:
        fail(f"rc={rc} calls={calls['n']}\n{out}")
    if "To read: orch 1.0.0 → 1.2.0 (a board of every running job across projects)" not in out:
        fail(out)
    if "First job: read orch:" not in out or "Behind: orch" in out:
        fail(out)
elif mode == "fresh-graphify":
    # n-fabf4b: the watch name is the command. PyPI is asked for the package.
    (one / "docs" / "upstream.toml").write_text(
        '[[watch]]\nname = "graphify"\nsource = "pypi:graphifyy"\npin = "0.9.93"\n',
        encoding="utf-8")
    fixture["releases"] = {
        "0.9.93": [{"upload_time_iso_8601": "2026-10-01T00:00:00Z"}],
        "0.9.97": [{"upload_time_iso_8601": "2026-10-27T00:00:00Z"}],
    }
    asked = []

    def fake_graphify(url, headers=None):
        calls["n"] += 1
        asked.append(url)
        if url != "https://pypi.org/pypi/graphifyy/json":
            raise SystemExit("asked " + url)
        return fixture

    u.fetch_json = fake_graphify
    rc, out = run(one, "--freshness")
    if rc != 0 or "Behind: graphify 0.9.93 → 0.9.97" not in out:
        fail(f"rc={rc}\n{out}")
    if asked != ["https://pypi.org/pypi/graphifyy/json"]:
        fail("asked " + repr(asked))
    tools = Path(base) / "uv-tools"
    (tools / "graphifyy").mkdir(parents=True)
    u.shutil_which = lambda name: "/usr/bin/uv" if name == "uv" else None

    def said_tools(command):
        if list(command) == ["uv", "tool", "dir"]:
            return str(tools)
        return ""

    u.said = said_tools
    found = u.where({"name": "graphify", "source": "pypi:graphifyy", "pin": "0.9.93"})
    paths = [text for kind, text in found if kind == "source"]
    if not any(str(tools / "graphifyy") in text for text in paths):
        fail("where missed graphifyy: " + repr(found))
elif mode == "idea-table":
    (one / "docs" / "upstream.toml").write_text(
        '[[watch]]\nname = "tool"\nsource = "pypi:tool"\npin = "1.2.0"\n\n'
        '[[watch]]\nname = "orch"\nkind = "idea"\nsource = "pypi:tool"\npin = "1.0.0"\n'
        'why = "an idea"\nlook_for = "a board of every running job across projects"\n',
        encoding="utf-8")
    rc, out = run(one)
    if rc != 0 or "To read: orch" not in out or "Newer:" in out:
        fail(f"rc={rc}\n{out}")
    if "An idea is not an upgrade" not in out:
        fail(out)
    cache = json.loads((one / ".git" / "upstream-cache.json").read_text(encoding="utf-8"))
    if cache.get("behind"):
        fail("an idea was counted behind: " + repr(cache["behind"]))
elif mode == "npm-scope":
    seen = {}

    def fake(url, headers=None):
        seen["url"] = url
        return {"versions": {"1.0.62": {}}, "time": {"1.0.62": "2026-10-20T00:00:00.000Z"}}

    u.fetch_json = fake
    rows = u.from_npm("@xai-official/grok")
    if seen.get("url") != "https://registry.npmjs.org/@xai-official%2Fgrok":
        fail("asked " + seen.get("url", ""))
    if not rows or rows[0]["version"] != "1.0.62":
        fail(repr(rows))
elif mode.startswith("pointer"):
    def pointer(body):
        seen = {}

        def fake(url):
            seen["url"] = url
            return body

        u.fetch_text = fake
        return seen

    def versions(seen, body):
        rows = u.SOURCES["pointer"]("https://x.ai/cli/stable")
        if seen.get("url") != "https://x.ai/cli/stable":
            fail("asked " + seen.get("url", ""))
        if [r["version"] for r in rows] != ["1.0.62"]:
            fail(body + " -> " + repr(rows))

    if mode == "pointer-text":
        versions(pointer("1.0.62\n"), "plain text")
    elif mode == "pointer-prose":
        versions(pointer("Grok CLI, stable channel\nversion 1.0.62\n"), "prose")
    elif mode == "pointer-json":
        versions(pointer('{"stable_version": "1.0.62"}'), "json")
    elif mode == "pointer-empty":
        pointer("<html>no release here</html>")
        try:
            u.SOURCES["pointer"]("https://x.ai/cli/stable")
        except u.Unreachable as err:
            if "returned no version" not in str(err):
                fail(str(err))
        else:
            fail("a pointer with no version was read as an answer")
    elif mode == "pointer-fresh":
        # The channel says 1.0.62; npm's 1.0.66 is the alpha channel and is
        # never asked. This is grok's row as it is written.
        (one / "docs" / "upstream.toml").write_text(
            '[[watch]]\nname = "grok"\nsource = "pointer:https://x.ai/cli/stable"\npin = "1.0.62"\n',
            encoding="utf-8")

        def no_json(url, headers=None):
            fail("a registry was asked: " + url)

        u.fetch_json = no_json
        pointer("1.0.62\n")
        rc, out = run(one, "--freshness")
        if rc != 0 or "Behind: nothing" not in out or "1.0.66" in out:
            fail(f"rc={rc}\n{out}")
    else:
        fail("unknown mode " + mode)
elif mode == "channel-fresh":
    # The stable channel is 2.1.304 and latest is 2.1.306; the row follows the
    # channel `claude doctor` names, so stable is current and latest is not asked.
    stable = "https://downloads.claude.ai/claude-code-releases/stable"
    (one / "docs" / "upstream.toml").write_text(
        f'[[watch]]\nname = "claude-code"\nsource = "pointer:{stable}"\npin = "2.1.304"\n',
        encoding="utf-8")
    asked = []

    def fake_text(url):
        asked.append(url)
        return {"https://downloads.claude.ai/claude-code-releases/stable": "2.1.304\n",
                "https://downloads.claude.ai/claude-code-releases/latest": "2.1.306\n"}.get(url, "")

    u.fetch_text = fake_text
    rc, out = run(one, "--freshness")
    if rc != 0 or "Behind: nothing" not in out or "2.1.306" in out:
        fail(f"rc={rc}\n{out}")
    if asked != [stable]:
        fail("asked " + repr(asked))
elif mode == "brew":
    seen = {}

    def fake(url, headers=None):
        seen["url"] = url
        return {"versions": {"stable": "2.1.2", "head": None}}

    u.fetch_json = fake
    rows = u.SOURCES["brew"]("opencode")
    if seen.get("url") != "https://formulae.brew.sh/api/formula/opencode.json":
        fail("asked " + seen.get("url", ""))
    if [r["version"] for r in rows] != ["2.1.2"]:
        fail(repr(rows))

    def empty(url, headers=None):
        return {"versions": {"stable": ""}}

    u.fetch_json = empty
    try:
        u.SOURCES["brew"]("opencode")
    except u.Unreachable as err:
        if "no stable version" not in str(err):
            fail(str(err))
    else:
        fail("a formula with no stable version was read as an answer")
elif mode == "npm-win":
    # The shape of the Windows launch, on every machine: the suite's Mac run
    # never starts CreateProcess, and a .cmd stand-in that the Mac run can
    # execute is how the last fix stayed green here and red on windows-latest.
    env = {"ComSpec": r"C:\Windows\System32\cmd.exe", "SystemRoot": r"C:\Windows"}
    cmd = u.npm_windows_argv(r"C:\Program Files\nodejs\npm.cmd", ["outdated", "--json"], env)
    if cmd != [r"C:\Windows\System32\cmd.exe", "/d", "/c", "npm", "outdated", "--json"]:
        fail(repr(cmd))
    upper = u.npm_windows_argv(r"C:\node\npm.CMD", ["outdated", "--json"], env)
    if upper != cmd:
        fail(repr(upper))
    exe = u.npm_windows_argv(r"C:\node\npm.exe", ["audit", "--json"], env)
    if exe != [r"C:\node\npm.exe", "audit", "--json"]:
        fail(repr(exe))
    bare = u.npm_windows_argv(r"C:\node\npm.bat", ["audit", "--json"], {"SystemRoot": r"C:\Windows"})
    expect = os.path.join(r"C:\Windows", "System32", "cmd.exe")
    if bare != [expect, "/d", "/c", "npm", "audit", "--json"]:
        fail(repr(bare))
elif mode.startswith("npm-"):
    tree = Path(base) / (mode + "-tree")
    bindir = Path(base) / (mode + "-bin")
    bindir.mkdir(parents=True, exist_ok=True)
    log = Path(base) / (mode + ".log")
    script = bindir / "npm"
    script.write_text(
        '#!/bin/sh\n'
        'printf \'%s %s\\n\' "$PWD" "$1" >> "$FAKE_NPM_LOG"\n'
        'case "$1" in\n'
        '  outdated) [ -n "${FAKE_NPM_SLEEP:-}" ] && /bin/sleep "$FAKE_NPM_SLEEP"; printf \'%s\' "$FAKE_NPM_OUTDATED"; exit "${FAKE_NPM_OUTDATED_RC:-1}";;\n'
        '  audit) [ -n "${FAKE_NPM_SLEEP:-}" ] && /bin/sleep "$FAKE_NPM_SLEEP"; printf \'%s\' "$FAKE_NPM_AUDIT"; exit "${FAKE_NPM_AUDIT_RC:-1}";;\n'
        'esac\n'
        'exit 0\n', encoding="utf-8", newline="\n")
    script.chmod(0o755)
    # The real npm on Windows is npm.cmd. CreateProcess (shell=False) appends
    # .exe only and will not start a .cmd; upstream.py runs the name `npm`
    # through cmd /c, which resolves npm.cmd by PATHEXT in this folder. The
    # script stays LF: a CRLF shebang is not a program. npm.cmd names bash by
    # a full path, because PATH below is only this folder. The exit code is
    # stored before the next line is parsed: `%ERRORLEVEL%` on the same line
    # as the program is still the previous one. The log path is the Git bash
    # form of the same file: a redirection there does not open C:\...
    if os.name == "nt":
        bash = shutil.which("bash") or shutil.which("sh")
        if not bash:
            fail("bash is not on PATH, so the stand-in npm cannot run")
        (bindir / "npm.cmd").write_text(
            '@echo off\n'
            f'"{bash}" "%~dp0npm" %*\n'
            'set RC=%ERRORLEVEL%\n'
            'exit /b %RC%\n',
            encoding="utf-8", newline="\r\n")
    def for_bash(path):
        text = os.fspath(path)
        if os.name != "nt":
            return text
        drive, rest = os.path.splitdrive(text)
        if drive:
            return "/" + drive[0].lower() + rest.replace("\\", "/")
        return text
    os.environ["FAKE_NPM_LOG"] = for_bash(log)
    if mode == "npm-none":
        tree.mkdir(parents=True, exist_ok=True)
    else:
        (tree / ".git").mkdir(parents=True, exist_ok=True)
        (tree / "package.json").write_text("{}", encoding="utf-8")
        (tree / "web").mkdir(parents=True, exist_ok=True)
        (tree / "web" / "package.json").write_text("{}", encoding="utf-8")
        (tree / "web" / "package-lock.json").write_text("{}", encoding="utf-8")
        (tree / "node_modules" / "dep").mkdir(parents=True, exist_ok=True)
        (tree / "node_modules" / "dep" / "package.json").write_text("{}", encoding="utf-8")
    if mode == "npm-ignored":
        # cargo's target/ is gitignored and still holds a package.json. The
        # empty .git above is not a repository until init, so check-ignore can match.
        (tree / "target" / "web").mkdir(parents=True, exist_ok=True)
        (tree / "target" / "web" / "package.json").write_text("{}", encoding="utf-8")
        (tree / "target" / "web" / "package-lock.json").write_text("{}", encoding="utf-8")
        (tree / ".gitignore").write_text("target/\n", encoding="utf-8")
        init = subprocess.run(
            ["git", "init", "-q"], cwd=tree,
            stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
        if init.returncode != 0:
            fail("git init failed: " + (init.stderr or ""))
    if mode == "npm-missing":
        os.environ["PATH"] = str(tree / "no-bin")
    elif mode == "npm-ignored":
        # The stand-in npm stays first. git has to be found too, or check-ignore cannot match.
        os.environ["PATH"] = str(bindir) + os.pathsep + os.environ.get("PATH", "")
    else:
        os.environ["PATH"] = str(bindir)
    os.environ["FAKE_NPM_OUTDATED"] = (
        '{"vite":{"current":"5.0.0","latest":"5.4.0"},'
        '"react":{"current":"18.0.0","latest":"18.3.1"}}')
    os.environ["FAKE_NPM_AUDIT"] = (
        '{"metadata":{"vulnerabilities":{"info":0,"low":0,"moderate":1,"high":2,'
        '"critical":0,"total":3}}}')
    os.environ.pop("FAKE_NPM_SLEEP", None)
    os.environ.pop("FAKE_NPM_OUTDATED_RC", None)
    if mode == "npm-slow":
        os.environ["FAKE_NPM_SLEEP"] = "5"
        os.environ["AI_BACKBONE_NPM_TIMEOUT"] = "0.3"
        u.NPM_TIMEOUT = 0.3
    if mode == "npm-fail":
        os.environ["FAKE_NPM_OUTDATED_RC"] = "2"
        os.environ["FAKE_NPM_OUTDATED"] = ""
    started = time.monotonic()
    rc, out = run(tree, "--npm")
    took = time.monotonic() - started
    calls = log.read_text(encoding="utf-8").splitlines() if log.exists() else []
    # Git bash logs a /c/... path; cmd would log C:\... Either way the folder
    # is the same one.
    calls = [c.replace("\\", "/") for c in calls]
    if mode == "npm-none":
        if rc != 0 or out != "" or calls:
            fail(f"rc={rc} calls={calls}\n{out}")
    elif mode == "npm-report":
        if rc != 0 or "=== NPM PACKAGES (2) ===" not in out:
            fail(f"rc={rc}\n{out}")
        if "2 outdated (react 18.0.0 → 18.3.1, vite 5.0.0 → 5.4.0)" not in out:
            fail(out)
        if "3 vulnerabilities (2 high, 1 moderate) -> npm audit" not in out:
            fail(out)
        if any("node_modules" in c for c in calls):
            fail("node_modules was read: " + repr(calls))
        if not any(c.endswith(" audit") and "/web" in c for c in calls):
            fail("audit was not asked of the folder with a lock file: " + repr(calls))
        if sum(1 for c in calls if c.endswith(" audit")) != 1:
            fail("audit was asked of a folder with no lock file: " + repr(calls))
    elif mode == "npm-ignored":
        probe = subprocess.run(
            ["git", "check-ignore", "-q", "--", "target/web/package.json"],
            cwd=tree, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if probe.returncode != 0:
            fail("fixture target/web/package.json is not ignored")
        if rc != 0 or "=== NPM PACKAGES (2) ===" not in out:
            fail(f"rc={rc}\n{out}")
        if "target" in out or any("target" in c for c in calls):
            fail("an ignored package.json was counted: " + repr(calls) + "\n" + out)
        if "2 outdated (react 18.0.0 → 18.3.1, vite 5.0.0 → 5.4.0)" not in out:
            fail(out)
        if "3 vulnerabilities (2 high, 1 moderate) -> npm audit" not in out:
            fail(out)
        if sum(1 for c in calls if c.endswith(" outdated")) != 2:
            fail("outdated was asked of an ignored folder: " + repr(calls))
        if sum(1 for c in calls if c.endswith(" audit")) != 1:
            fail("audit was asked of an ignored folder: " + repr(calls))
    elif mode == "npm-slow":
        if rc != 0 or "could not check outdated (slow)" not in out or took > 3:
            fail(f"rc={rc} took={took:.1f}\n{out}")
    elif mode == "npm-fail":
        if rc != 0 or "could not check outdated (npm said 2)" not in out:
            fail(f"rc={rc}\n{out}")
    elif mode == "npm-missing":
        if rc != 0 or "could not check (npm is not installed)" not in out:
            fail(f"rc={rc}\n{out}")
    else:
        fail("unknown mode " + mode)
else:
    fail("unknown mode " + mode)
PY
fresh035() { env -u AI_BACKBONE_OFFLINE -u WORKER "$py" "$tmp/spec035.py" "$rootw" "$1" "$tmp/spec035"; }
check "a shared copy under a day old is not asked again"          "fresh035 age-fresh"
check "a shared copy a day old is asked again"                    "fresh035 age-stale"
check "--refresh asks even when the copy is new"                  "fresh035 refresh"
check "two projects share one lookup of one source"               "fresh035 shared"
check "offline, with no copy, says so and does not ask"           "fresh035 offline-empty"
check "offline, an old copy is shown with its age"                "fresh035 offline-stale"
check "a rate limit keeps the last result and is not asked again" "fresh035 rate"
check "past the time budget the last result is kept"              "fresh035 slow"
check "a call already in flight stops at the time that is left"       "fresh035 budget-cap"
check "session start's block names what is behind and one first job"  "fresh035 fresh"
check "offline, the block shows the last result, its age, and why"    "fresh035 fresh-offline"
check "offline, with no copy, the block says so and still exits 0"    "fresh035 fresh-empty"
check "past ten seconds the block keeps the last result and says slow" "fresh035 fresh-slow"
check "a pin the file does not hold is the job when nothing is behind" "fresh035 fresh-moved"
check "an idea's newer release is to read, never behind"              "fresh035 fresh-idea"
check "FRESHNESS asks PyPI for graphifyy and Behind names graphify, and where() finds that folder" "fresh035 fresh-graphify"
check "the table lists an idea apart, and not as newer"             "fresh035 idea-table"
check "a scoped npm package is asked with the slash encoded"        "fresh035 npm-scope"
check "a channel pointer says the one version the channel holds"    "fresh035 pointer-text"
check "a pointer that writes its version in prose is read the same"  "fresh035 pointer-prose"
check "a pointer that answers JSON is read too"                     "fresh035 pointer-json"
check "a pointer with no version is unreachable, never current"      "fresh035 pointer-empty"
check "a stable channel is not compared with a registry's alpha"     "fresh035 pointer-fresh"
check "a worker CLI is compared with the channel it was installed on" "fresh035 channel-fresh"
check "a Homebrew formula says the stable version brew would install" "fresh035 brew"
check "Windows runs npm.cmd through cmd, and npm.exe as itself"    "fresh035 npm-win"
check "npm outdated and audit are read for every package.json, node_modules skipped" "fresh035 npm-report"
check "a package.json inside a gitignored target/ is not outdated or vulnerable" "fresh035 npm-ignored"
check "no package.json means no npm call and no line"                "fresh035 npm-none"
check "a slow npm is one line, and the session goes on"              "fresh035 npm-slow"
check "a failing npm is a could-not-check line"                      "fresh035 npm-fail"
check "npm missing is said, never a failed session"                  "fresh035 npm-missing"
check "session-start reads npm next to the RustSec check" \
  "grep -q 'upstream.py --npm' '$root/.ai-backbone/core.just' && [ \"\$(awk '/upstream.py --advisories session/{a=NR} /upstream.py --npm/{n=NR} END{print (n>a && a>0) ? \"next\" : \"not-next\"}' '$root/.ai-backbone/core.just')\" = next ]"
check "the backbone reads grok from its stable channel, not from npm" \
  "grep -qx 'source = \"pointer:https://x.ai/cli/stable\"' '$root/docs/upstream.toml' && ! grep -qx 'source = \"npm:@xai-official/grok\"' '$root/docs/upstream.toml'"
check "and reads claude-code at the stable channel its doctor prints, not npm's newest" \
  "grep -qx 'source = \"pointer:https://downloads.claude.ai/claude-code-releases/stable\"' '$root/docs/upstream.toml' && grep -qx 'pin = \"2.1.304\"' '$root/docs/upstream.toml' && ! grep -qx 'source = \"npm:@anthropic-ai/claude-code\"' '$root/docs/upstream.toml' && grep -q 'claude doctor' '$root/docs/upstream.toml'"
check "the backbone's tool pins name a version for just, prek, graphify, uv, gitleaks and the actions" \
  "(for n in just prek graphify uv gitleaks; do awk -v n=\"\$n\" '/^\\[\\[watch\\]\\]/{w=0} \$0==\"name = \\\"\"n\"\\\"\"{w=1} w&&/^pin = \"[^\"]+\"\$/{f=1} END{exit !f}' '$root/docs/upstream.toml' || exit 1; done) && grep -qx 'pin = \"v7\"' '$root/docs/upstream.toml'"
check "the backbone watches grok and claude-code, and no longer zed or the two ideas (they are references in the backbone's brain)" \
  "grep -qx 'source = \"pointer:https://x.ai/cli/stable\"' '$root/docs/upstream.toml' && grep -qx 'source = \"pointer:https://downloads.claude.ai/claude-code-releases/stable\"' '$root/docs/upstream.toml' && ! grep -q 'zed-industries\\|agent-orchestrator\\|claude-delegator' '$root/docs/upstream.toml'"
check "the backbone watches opencode on the Homebrew formula it installs from" \
  "grep -qx 'name = \"opencode\"' '$root/docs/upstream.toml' && grep -qx 'source = \"brew:opencode\"' '$root/docs/upstream.toml' && grep -qx 'pin = \"2.1.2\"' '$root/docs/upstream.toml' && ! grep -qx 'source = \"github:anomalyco/opencode\"' '$root/docs/upstream.toml'"
check "the backbone watches kimi on the Homebrew formula it installs from" \
  "grep -qx 'name = \"kimi\"' '$root/docs/upstream.toml' && grep -qx 'source = \"brew:kimi-code\"' '$root/docs/upstream.toml' && grep -qx 'pin = \"2.4.0\"' '$root/docs/upstream.toml'"
check "the two ideas are no longer pinned: the watch list holds no idea row" \
  "! grep -q 'kind = \"idea\"' '$root/docs/upstream.toml' && ! grep -q '^look_for = ' '$root/docs/upstream.toml' && ! grep -qx 'pin = \"v0.14.3\"' '$root/docs/upstream.toml' && ! grep -qx 'pin = \"8e2ea57c9b8e6f0790b1596d98e35632ca48a59c\"' '$root/docs/upstream.toml'"
check "the template says what an idea row is" "grep -q 'kind' '$root/.ai-backbone/templates/upstream.toml' && grep -q 'look_for' '$root/.ai-backbone/templates/upstream.toml'"
check "just upstream --refresh is a real run, and offline it says so" \
  "says offline env AI_BACKBONE_UPSTREAM_CACHE='$tmp/spec035-refresh' just upstream --refresh && env AI_BACKBONE_UPSTREAM_CACHE='$tmp/spec035-refresh' just upstream --refresh >/dev/null"
# session-start's two weekly blocks ask GitHub and the registries. Offline they
# are skipped, and an offline session does not use up the week either.
rm -f .git/ai-backbone.last-check .git/ai-backbone.last-upstream
check "session-start asks no source for anything while offline" "! says '[(]weekly check[)]' just session-start && [ ! -e .git/ai-backbone.last-upstream ] && [ ! -e .git/ai-backbone.last-check ]"
check "session-start shows FRESHNESS, and offline it still finishes" "says '=== FRESHNESS' just session-start && says offline just session-start"
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
routine_pid=$!
# Until the first run holds the lock: a second on Windows was not always enough.
i=0; until [ -s "$lock/pid" ] || [ $i -ge 50 ]; do sleep 0.2; i=$((i+1)); done
check "a second run while one is going does nothing"  "says 'already going' env AI_AGENT_CMD='true {prompt}' sh .ai-backbone/routine.sh"
suite_wait "$routine_pid" 30
check "the lock is gone once the first run ends"      "[ ! -e '$lock' ]"
git checkout -q -- .pre-commit-config.yaml

fi
if lane_wants plain; then
section "a project without a language"
if ( cd "$root" && just new-project "$tmp/plain" ) >/dev/null 2>&1; then ok "new-project without lang runs"; else bad "new-project without lang runs"; fi
check "no Turkish alias when the language is not tr"  "! grep -q '^alias yedekle' '$tmp/plain/Justfile' && grep -q 'Aliases in your own language' '$tmp/plain/Justfile'"
# The Rust example must be true for a workspace at the root as well as in server/ (3.20.0).
for d in ws nows; do mkdir -p "$tmp/$d"; printf "import? 'stack.just'\n" > "$tmp/$d/Justfile"; cp "$root/.ai-backbone/examples/stack-rust.just" "$tmp/$d/stack.just"; done; touch "$tmp/ws/Cargo.toml"
check "stack rust finds a workspace at the root"      "says '^\.$' sh -c \"cd '$tmp/ws' && just --evaluate server_dir\""
check "stack rust assumes server/ otherwise"          "says '^server$' sh -c \"cd '$tmp/nows' && just --evaluate server_dir\""
check "stack rust ships fmt and test-fast"            "says 'fmt' sh -c \"cd '$tmp/nows' && just --summary\" && says 'test-fast' sh -c \"cd '$tmp/nows' && just --summary\""

fi
if lane_wants checks; then
section "checks on every push"
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
cp .github/workflows/checks.yml "$tmp/checks-fmt.yml"
perl -pi -e 's/^.*cargo fmt --check.*\n//' .github/workflows/checks.yml
check "without cargo fmt --check the gate names the miss" "! just ci-check && says 'no cargo fmt --check' just ci-check"
cp "$tmp/checks-fmt.yml" .github/workflows/checks.yml
check "the rust checks run cargo fmt --check" "grep -q 'cargo fmt --check' .github/workflows/checks.yml && says 'still in force' just ci-check"
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
# session-start names the jobs a red run lost, and says when gh is not signed
# in, which answered nothing and looked like green (spec 026). The weekly checks
# are stamped as done and every address is dead, so nothing leaves the machine.
mkdir -p "$tmp/gh26"; cat > "$tmp/gh26/gh" <<'EOF'
#!/bin/sh
case "$1 $2" in
  "auth token") [ -z "${GH26_OUT:-}" ] || exit 1; echo token ;;
  "run list") printf 'checks\tcompleted\tfailure\t42\n' ;;
  "run view") [ "$3" = 42 ] && echo "rust, lint" ;;
esac
EOF
chmod +x "$tmp/gh26/gh"
touch "$(git rev-parse --git-path ai-backbone.last-check)" "$(git rev-parse --git-path ai-backbone.last-upstream)"
ss26() { rm -f "$(git rev-parse --git-path ai-backbone.last-ci)"; env -u AI_BACKBONE_OFFLINE AI_BACKBONE="$tmp/none" https_proxy=$dead http_proxy=$dead HTTPS_PROXY=$dead HTTP_PROXY=$dead no_proxy= NO_PROXY= PATH="$tmp/gh26:$PATH" "$@" just session-start; }
check "session-start names the jobs a red run lost, and the run" "says '^Checks: checks failure on this commit [(]failed: rust, lint[)] -> just ci 42\$' ss26"
check "and says when gh is not signed in" "says '^Checks: gh is not signed in here' ss26 GH26_OUT=1"
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

fi
if lane_wants adopt; then
section "adopting an existing repo"
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
fi
if lane_wants build; then
section "build output (spec 015)"
# One throwaway project on the Rust layer, its workspace at the root, and two
# fakes first on PATH: a cargo that says what it was asked and with how many
# jobs, and a ps that lists a few programs and, for its first PS_BUSY calls, a
# cargo (PS_NAME for another name; PS_FAIL=1 for a ps that cannot list, =empty
# for one that lists nothing). Nothing here compiles, and nothing reads this
# machine's own processes or its own build folder.
bo="$tmp/bo"; mkdir -p "$bo/bin" "$bo/du" "$bo/shared"
cat > "$bo/bin/ps" <<'EOF'
#!/bin/sh
# Asked who is whose parent (the build queue, spec 027), the real ps answers,
# and the call is not counted: the counts below are looks for a build.
case "$*" in *ppid=*) exec "$REAL_PS" "$@" ;; esac
n=$(( $(cat "$PS_COUNT" 2>/dev/null || echo 0) + 1 )); echo "$n" > "$PS_COUNT"
case "${PS_FAIL:-}" in 1) echo "ps: cannot list processes" >&2; exit 1 ;; empty) exit 0 ;; esac
# Asked for states too (-o stat=), each line starts with one: S, or T for a
# build stopped with Ctrl-Z (PS_STOPPED=1).
st=""; case "$*" in *stat=*) st="S " ;; esac
for p in /sbin/init "/usr/bin/bash" "Google Chrome Helper" rust-analyzer; do echo "$st$p"; done
# PS_LATER=k: a build that starts after the k-th look. Asked for command
# lines (-o args=, the trim), it also prints PS_USES as one, if set.
if [ "$n" -le "${PS_BUSY:-0}" ] || { [ -n "${PS_LATER:-}" ] && [ "$n" -gt "$PS_LATER" ]; }; then
  [ -n "$st" ] && [ "${PS_STOPPED:-}" = 1 ] && st="T "
  echo "$st/home/someone/.rustup/toolchains/stable/bin/${PS_NAME:-cargo}"
  case "$*" in *args=*) [ -z "${PS_USES:-}" ] || echo "$PS_USES" ;; esac
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
# Asked for the workspace's crates, it answers as cargo 1.97 does, with the
# blank line between members (spec 028 review).
if [ "$1" = tree ]; then printf 'bo v0.1.0 (/p)\n\nbo-core v0.1.0 (/p/core)\n'; exit 0; fi
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
# One setting per machine caps heavy work (spec 026): a nice level and a job
# count, read by _heavy. Given through git's environment, so nothing is written.
cap() { bw env GIT_CONFIG_COUNT=2 GIT_CONFIG_KEY_0=ai-backbone.jobs GIT_CONFIG_VALUE_0="$1" GIT_CONFIG_KEY_1=ai-backbone.nice GIT_CONFIG_VALUE_1="$2" "${@:3}"; }
check "_heavy is nothing until the machine says otherwise" "[ -z \"\$(just _heavy)\" ]"
check "with a cap and a nice level it prints the prefix for both" "[ \"\$(cap 3 15 just _heavy)\" = 'nice -n 15 env CARGO_BUILD_JOBS=3 RUST_TEST_THREADS=3 CMAKE_BUILD_PARALLEL_LEVEL=3 MAKEFLAGS=-j3' ]"
# A workspace moved since its last build cleans its own crates once (spec 028).
gd=$(git rev-parse --git-dir); printf '/somewhere/else' > "$gd/ai-backbone.cargo-root"
check "a moved Rust workspace cleans its own crates, dev and release, before it builds, once" "out=\$(bw env BUILD_WAIT_MINUTES=0 just check 2>&1); grep -q 'This workspace moved since its last build' <<<\"\$out\" && grep -q 'fake cargo clean -p bo ' <<<\"\$out\" && grep -q 'fake cargo clean -p bo-core ' <<<\"\$out\" && grep -q 'fake cargo clean --release -p bo ' <<<\"\$out\" && grep -q 'fake cargo clean --release -p bo-core ' <<<\"\$out\" && ! says 'workspace moved' bw env BUILD_WAIT_MINUTES=0 just check"
check "a MAKEFLAGS already set is left as it is" "! says MAKEFLAGS cap 3 0 env MAKEFLAGS=-j1 just _heavy && says 'CARGO_BUILD_JOBS=3' cap 3 0 env MAKEFLAGS=-j1 just _heavy"
check "half is half the cores, and nonsense is ignored" "[ \"\$(cap half 99 just _heavy)\" = 'env CARGO_BUILD_JOBS=$half RUST_TEST_THREADS=$half CMAKE_BUILD_PARALLEL_LEVEL=$half MAKEFLAGS=-j$half' ] && [ -z \"\$(cap many x just _heavy)\" ]"
check "the Rust layer builds under the machine's cap" "says 'fake cargo check --workspace --all-targets jobs=1' cap 1 15 env BUILD_WAIT_MINUTES=0.1 just check"
check "and a wait that gives up keeps the machine's cap when it is lower than half" "out=\$(cap 1 0 env PS_BUSY=99 BUILD_WAIT_MINUTES=0.02 just check 2>&1); grep -q 'jobs=1\$' <<<\"\$out\" && grep -q 'with your own CARGO_BUILD_JOBS=1' <<<\"\$out\""

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
# A save the lint hook would not run on does not wait for anybody's build (spec 029).
mkdir -p docs && printf 'a line\n' > docs/note.md && git add -A >/dev/null 2>&1
out=$(bw env PS_BUSY=1 BUILD_WAIT_MINUTES=0.05 just save "docs: a note while another build runs" 2>&1)
check "and a save of docs alone does not wait, and saves" "! grep -q '^Another build is running' <<<\"\$out\" && [ \"\$(git log -1 --format=%s)\" = 'docs: a note while another build runs' ]"

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
fi
if lane_wants flutter; then
section "the Flutter layer (spec 015)"
fl="$tmp/fl"; mkdir -p "$fl/fakes" "$fl/shim" "$fl/linux" "$fl/ws"
cat > "$fl/fakes/flutter" <<'EOF'
#!/bin/sh
echo "flutter $* @ ${PWD##*/}" >> "$FL_LOG"
case "$1 $2" in
  "analyze "*) [ -n "${FL_ANALYZE_FAILS:-}" ] && { echo "1 issue found."; exit 1; } ;;
  "pub upgrade") printf '%b\n' "${FL_DRY:-Resolving dependencies...\nNo dependencies would change.}" ;;
  "build apk") echo "Execution failed: Error while executing process /jdk/bin/jlink"; exit 1 ;;
  "test "*) [ -n "${FL_TEST_SILENT:-}" ] && exec sleep 30 ;;
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
mkdir -p "$fl/darwin"
printf '#!/bin/sh\necho Darwin\n' > "$fl/darwin/uname"
chmod +x "$fl/fakes/flutter" "$fl/fakes/dart" "$fl/linux/uname" "$fl/darwin/uname"
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
check "its header lists what it does not do yet, each with its event" "( for w in 'release signing' 'store upload' 'build-number bump' 'flavors' 'a Mac rehearsal of' 'golden tests' 'MCP server' 'toolchain line in'; do grep -q \"^#.*\$w\" '$L' || exit 1; done )"
# The names are the project's own words (its apps, the earlier ones) and are
# private: they live in brain/private-names.txt on the maintainer's machine,
# one per line, and never in this file, because the repository is public
# (3.27.1). A home folder, which stands for anything of one machine, is looked
# for everywhere.
names=$(awk '!/^#/ && NF' "$root/brain/private-names.txt" 2>/dev/null | paste -s -d '|' - || true)
check "no project or machine of the project it came from is named" "! grep -qiE '${names:+$names|}/Users/|/home/' '$L' '$W'"

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
# Device tests pick an emulator by its AVD name or its port, never the first
# line adb prints. A run that writes nothing is stopped, and a busy machine
# is said before Flutter is asked. The launchd file is checked as text.
mkdir -p "$fl/adb"
cat > "$fl/adb/adb" <<'EOF'
#!/bin/sh
if [ "$1" = devices ]; then printf 'List of devices attached\nemulator-5554\tdevice\nemulator-5556\tdevice\n'; exit 0; fi
if [ "$1" = -s ] && [ "$3" = emu ]; then
  case "$2" in emulator-5554) printf 'Pixel_API_35\n' ;; emulator-5556) printf 'Other\n' ;; esac
fi
exit 0
EOF
chmod +x "$fl/adb/adb"
dev() { env PATH="$fl/adb:$fl/fakes:$PATH" FL_LOG="$fl/log" FLUTTER_LOAD_NOW=0.1 FLUTTER_FREE_NOW=4000 "$@"; }
check "a device is chosen by its AVD name, never by being listed first" "says '^emulator-5554$' dev just _device-serial Pixel_API_35 && says '^emulator-5556$' dev just _device-serial '""' 5556"
check "with no name and no port, the first adb line is refused" "! dev just _device-serial >/dev/null 2>&1 && says 'not a choice' dev just _device-serial"
: > "$fl/log"
check "test-device asks flutter test for that emulator" "dev just app=app test-device Pixel_API_35 >/dev/null 2>&1 && grep -qx 'flutter test -d emulator-5554 @ app' '$fl/log'"
: > "$fl/log"
check "a device test that writes nothing is stopped, and the log is kept" "! dev env FL_TEST_SILENT=1 FLUTTER_SILENCE_SECONDS=2 just app=app test-device Pixel_API_35 >/dev/null 2>&1 && says 'wrote nothing for 2 seconds' dev env FL_TEST_SILENT=1 FLUTTER_SILENCE_SECONDS=2 just app=app test-device Pixel_API_35 && [ -n \"\$(ls brain/05-files/device-test-*.log 2>/dev/null)\" ]"
: > "$fl/log"; rm -rf brain
check "a busy machine is said, and flutter is not asked" "! dev env FLUTTER_LOAD_NOW=20 FLUTTER_LOAD_MAX=8 just app=app test-device Pixel_API_35 >/dev/null 2>&1 && says 'This machine is busy' dev env FLUTTER_LOAD_NOW=20 just app=app test-device Pixel_API_35 && [ ! -s '$fl/log' ]"
check "the emulator plist is a one-shot interactive agent and starts nothing" "says 'launchd was not asked' env PATH='$fl/darwin:'\"\$PATH\" ANDROID_HOME=/opt/android JAVA_HOME=/opt/java just emulator-plist Pixel_API_35 5554 '$fl/emu.plist' && grep -q '<key>KeepAlive</key><false/>' '$fl/emu.plist' && grep -q '<key>ProcessType</key><string>Interactive</string>' '$fl/emu.plist' && grep -q '<string>-port</string>' '$fl/emu.plist' && grep -q '<string>5554</string>' '$fl/emu.plist' && grep -q '<key>PATH</key>' '$fl/emu.plist' && grep -q 'ANDROID_HOME' '$fl/emu.plist' && grep -q 'JAVA_HOME' '$fl/emu.plist' && [ ! -s '$fl/log' ]"
check "emulator-plist refuses on a machine that is not a Mac and writes nothing (n-ae82d7)" "! env PATH='$fl/linux:'\"\$PATH\" just emulator-plist Pixel_API_35 5554 '$fl/nope.plist' >/dev/null 2>&1 && says 'needs macOS' env PATH='$fl/linux:'\"\$PATH\" just emulator-plist Pixel_API_35 5554 '$fl/nope.plist' && [ ! -e '$fl/nope.plist' ]"
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
# hook: the backlog lines of 2026-09-22 (one Flutter project, three) and 2026-09-23 (the same,
# one). A throwaway project of its own; the commits planted below skip the
# hooks, which are not what is tested, and prek is a stand-in where hooks are.
fi
if lane_wants ideas; then
section "spec 015: the other ideas"
o="$tmp/s15"
( cd "$root" && just new-project "$o" ) >/dev/null 2>&1
cd "$o" || exit 1
# A reference that has no address: an old repo of the person's own (a Flutter project kept
# three earlier repositories like that, moved into .references/ by hand). A git repo is
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
printf '[[rename]]\nold  = "levels/"\nnew  = "src/levels/"\ndate = "2026-09-22"\n' > docs/renames.toml
cat > docs/notes.md <<'MD'
# Notes

The entry point is `server/src/main.rs:1`, and `docs/old-page.md` said why.
Fine: `backend/src/main.rs`, `owner/repo`, `Node.js`, `docs/never-was.md`, `https://example.com/server/x`.
Not paths: `cargo run -p server`, `docs/specs/NNN-<name>.md`, `server/*.rs`, `out/report.txt`, `.archive/`.
```bash
cat server/src/main.rs levels/
```
The levels live in levels/ still.
Renamed once: `levels/` became `src/levels/`, and src/levels/x is fine.
MD
printf 'It began in `server/src/main.rs`.\n' >> docs/adr/0001-first-choice.md
out=$(just stale 2>&1); rc=$?
check "stale finds a path whose folder was renamed, as file:line" "grep -qF 'docs/notes.md:3: \`server/src/main.rs:1\` is no longer here' <<<\"\$out\""
check "and a page that was deleted"                    "grep -qF 'docs/notes.md:3: \`docs/old-page.md\` is no longer here' <<<\"\$out\""
check "and an old name from docs/renames.toml, fenced or not" "grep -qF 'docs/notes.md:9: \`levels/\` is \`src/levels/\` now (renamed 2026-09-22)' <<<\"\$out\" && grep -qF 'docs/notes.md:7: \`levels/\`' <<<\"\$out\""
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
check "and the Swift layer's lint ends with it too, never failing on it" "grep -q '^    just stale || true\$' '$root/.ai-backbone/examples/stack-swift.just' && grep -q '^    just stale || true\$' '$root/.ai-backbone/examples/stack-rust.just'"
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

fi
if lane_wants notes; then
section "notes between projects (spec 022)"
# Two projects made the way a person makes them, next to a stand-in backbone,
# so the search never reaches this machine's own folders.
pn="$tmp/pn"; mkdir -p "$pn/ai-backbone/.ai-backbone"
cp "$root/.ai-backbone/manifest.txt" "$root/.ai-backbone/routine.md" "$pn/ai-backbone/.ai-backbone/"; : > "$pn/ai-backbone/.ai-backbone/core.just"
( cd "$root" && just new-project "$pn/alpha" tr && just new-project "$pn/Beta Co" en ) >/dev/null 2>&1
pnote() { ( cd "$pn/alpha" && env AI_BACKBONE="$pn/ai-backbone" just project-note "$@" ); }
inbox="$pn/beta-co/brain/notes-from-projects.md"
check "project-note leaves a dated line with the sender's name in the other project's brain/" "pnote beta-co \"the name is 'Kırmızı Balık'
and a second line\" && grep -qx -- \"- \\[ \\] $(date +%Y-%m-%d), from alpha: the name is 'Kırmızı Balık' and a second line\" '$inbox'"
check "it finds a project by the name in its AGENTS.md too, and keeps a record in the sender's brain/" "pnote 'Beta Co' 'second' && [ \$(grep -c '^- \\[ \\]' '$inbox') -eq 2 ] && grep -q ', to Beta Co: second\$' '$pn/alpha/brain/notes-to-projects.md'"
# A project made directly beside the umbrella folder, one level higher than the
# backbone's parent (n-88393e): found too.
( cd "$root" && just new-project "$tmp/direct" tr ) >/dev/null 2>&1
check "a project one folder above the umbrella folder is found too" "pnote direct 'made beside the umbrella folder' && grep -q ', from alpha: made beside the umbrella folder\$' '$tmp/direct/brain/notes-from-projects.md'"
check "it runs nothing a note asks it to" "pnote beta-co '\$(touch $tmp/PWNED-pn) \`touch $tmp/PWNED-pn\`' && [ ! -e '$tmp/PWNED-pn' ]"
check "and commits nothing, in either project" "[ -z \"\$(git -C '$pn/alpha' status --porcelain)\" ] && [ -z \"\$(git -C '$pn/beta-co' status --porcelain)\" ]"
check "the other project's session-start shows its open notes, oldest first, and how to close one" "o=\$(cd '$pn/beta-co' && just session-start 2>&1); grep -q '^=== NOTES FROM OTHER PROJECTS (3 open, oldest first) ===' <<<\"\$o\" && [[ \"\$(awk '/^=== NOTES FROM OTHER/ { getline; print; exit }' <<<\"\$o\")\" == *'Kırmızı Balık'* ]] && grep -q 'change its - \\[ \\] to - \\[x\\]' <<<\"\$o\""
perl -pi -e 's/^- \[ \]/- [x]/ if $. == 7' "$inbox"
for i in 1 2 3 4 5; do pnote beta-co "more $i" >/dev/null 2>&1; done
check "a ticked note is not shown, and more than five are counted, not printed" "o=\$(cd '$pn/beta-co' && just session-start 2>&1); grep -q '(7 open, oldest first)' <<<\"\$o\" && ! grep -q 'Kırmızı Balık' <<<\"\$o\" && grep -q 'and 2 more in brain/notes-from-projects.md' <<<\"\$o\" && [ \$(grep -c '^- \\[ \\] ' <<<\"\$o\") -eq 5 ]"
check "a project that is not there is refused, naming the ones that are" "! pnote nobody x && says 'No project named nobody .* Projects there: .*Beta Co' pnote nobody x"
check "and so is this project itself, and an empty note" "! pnote alpha x && says 'is this project' pnote alpha x && ! pnote beta-co '' && ! pnote beta-co '   '"
perl -pi -e 's/^- \[ \]/- [x]/' "$inbox"
pnote beta-co "$(printf 'ğ%.0s' $(seq 1 300))" >/dev/null 2>&1
check "a long note in Turkish letters is cut by letter, never inside one" "o=\$(cd '$pn/beta-co' && just session-start 2>&1); grep -q 'ğğğ\\.\\.\\.\$' <<<\"\$o\" && perl -MEncode -e 'decode(\"UTF-8\", \$ARGV[0], Encode::FB_CROAK)' \"\$o\""
perl -pi -e 's/^\| *project *\|.*/| project | İzmir Şube |/' "$pn/beta-co/AGENTS.md"
check "a project name in Turkish capitals is found in small letters, and the other way" "pnote 'izmir şube' x && pnote 'İZMİR ŞUBE' y && [ \$(grep -c ', from alpha: [xy]\$' '$inbox') -eq 2 ]"
# A second project with the same folder name, one folder down.
mkdir -p "$pn/work/beta-co/.ai-backbone" && : > "$pn/work/beta-co/.ai-backbone/core.just"
check "two projects of one name: refused, naming each by its folder" "! pnote Beta-Co z && says 'just project-note work/beta-co' pnote Beta-Co z && says 'just project-note beta-co ' pnote Beta-Co z"
check "and the folder names the one meant" "pnote beta-co w && grep -q ', from alpha: w\$' '$inbox'"
# The backbone folder itself is reachable by its name, into its own brain/,
# never its public backlog (spec 026).
git -C "$pn/ai-backbone" init -q; printf 'brain/\n' > "$pn/ai-backbone/.gitignore"
check "project-note reaches the backbone folder, into its brain/" "pnote ai-backbone 'the task is done' && grep -q ', from alpha: the task is done\$' '$pn/ai-backbone/brain/notes-from-projects.md'"
# A note that lands while a session works is shown by the next save or
# session-end, once, and session-start marks what it showed (spec 026).
( cd "$pn/beta-co" && just session-start >/dev/null 2>&1 )
check "after session-start, nothing is new" "o=\$(cd '$pn/beta-co' && just _notes-new 2>&1); [ -z \"\$o\" ]"
pnote beta-co "arrived mid-session" >/dev/null 2>&1
check "a note that arrived since is shown by the next save, and only once" "printf 'x\\n' > '$pn/beta-co/docs/mid.md'; o=\$(cd '$pn/beta-co' && just save 'docs: mid' 2>&1); grep -q '^=== A NOTE FROM ANOTHER PROJECT ARRIVED (1 new' <<<\"\$o\" && grep -q 'arrived mid-session' <<<\"\$o\" && o2=\$(cd '$pn/beta-co' && just _notes-new 2>&1) && [ -z \"\$o2\" ]"
pnote beta-co "arrived late" >/dev/null 2>&1
check "and by session-end" "says 'arrived late' bash -c 'cd \"$pn/beta-co\" && just session-end'"
perl -ni -e 'print unless /arrived (mid-session|late)/' "$inbox"
pnote beta-co "after a tidy-up" >/dev/null 2>&1
check "a note is new even after older lines were deleted above it" "says 'after a tidy-up' bash -c 'cd \"$pn/beta-co\" && just _notes-new'"
sed -i.bak '/^brain/d' "$pn/beta-co/.gitignore" && rm -f "$pn/beta-co/.gitignore.bak"
lines=$(wc -l < "$inbox" | tr -d ' ')
check "and a project that does not keep brain/ out of git gets nothing" "! pnote beta-co x && says 'could be committed' pnote beta-co x && [ \$(wc -l < '$inbox' | tr -d ' ') -eq $lines ]"
# ── spec 016: project versions ──
# A project's own version: cut by `just release` at a meaningful point, read
# from the kinds of the commits since the last one, written into CHANGELOG.md,
# tagged, and carried to GitHub with the backup. A throwaway project; the
# commits planted below skip the hooks, the release commit does not.
fi
if lane_wants versions; then
section "project versions (spec 016)"
pv="$tmp/pv"
( cd "$root" && just new-project "$pv" ) >/dev/null 2>&1
cd "$pv" || exit 1
git add -A >/dev/null 2>&1; git commit -qm "chore: the project" --no-verify >/dev/null 2>&1 || true
pc() { echo "$2" >> "f-$1.txt"; git add -A; git commit -qm "$2" --no-verify; }
has_tag() { git rev-parse -q --verify "refs/tags/$1" >/dev/null; }
entry() { awk -v v="$1" 'index($0, "## [" v "]") == 1 { on = 1; next } on && /^## / { exit } on' CHANGELOG.md | sed '/./,$!d'; }
unrel() { awk '/^## \[Unreleased\]/ { on = 1; next } on && /^## / { exit } on' CHANGELOG.md | sed '/./,$!d'; }
# The CalVer version this month's nth release takes (spec 039).
cal() { printf '%s.%s.%s' "$(date +%y)" "$(date +%m | sed 's/^0//')" "$1"; }
# A release is two runs since spec 022: the first drafts the notes into
# [Unreleased] and stops, the second releases what they say.
rel() { just release "$@" >/dev/null 2>&1; just release "$@"; }
pc a "feat: a first thing — with a long tail nobody reads in a changelog"
check "no version yet: doctor says the first is this month's CalVer" "says 'first just release makes it $(date +%y)\\.[0-9]+\\.[0-9]+, when a spec is done' repo_doctor"
out=$(just release 2>&1)
check "the first run shows the drafted notes and stops: nothing tagged, nothing saved" "! has_tag v$(cal 0) && grep -q '^Not released yet: the notes for v$(cal 0)' <<<\"\$out\" && grep -q '^  - a first thing\$' <<<\"\$out\" && [ \"\$(unrel)\" = \"\$(printf '### Added\\n- a first thing')\" ] && [ \"\$(git log -1 --format=%s)\" = 'feat: a first thing — with a long tail nobody reads in a changelog' ]"
out=$(just release 2>&1)
check "the first release is this month's YY.M.0" "has_tag v$(cal 0) && grep -q '^Released v$(cal 0)' <<<\"\$out\""
check "an annotated tag, on a release commit" "[ \"\$(git cat-file -t v$(cal 0))\" = tag ] && [ \"\$(git log -1 --format=%s)\" = 'chore(release): v$(cal 0)' ] && [ \"\$(git rev-parse v$(cal 0)^{commit})\" = \"\$(git rev-parse HEAD)\" ]"
check "CHANGELOG.md is made, the entry drafted from the commits, each cut at its dash" "grep -qx '## \\[$(cal 0)\\] - $(date +%Y-%m-%d)' CHANGELOG.md && [ \"\$(entry $(cal 0))\" = \"\$(printf '### Added\\n- a first thing')\" ] && grep -qx '## \\[Unreleased\\]' CHANGELOG.md && grep -q 'keepachangelog.com' CHANGELOG.md && grep -q 'CalVer YY.M.PATCH (https://calver.org), which is also valid' CHANGELOG.md"
check "doctor says the version" "says 'version v$(cal 0), at this save' repo_doctor"
out=$(just release 2>&1)
check "nothing since the last version: it says so and changes nothing" "grep -q 'Nothing to release: no save since v$(cal 0)' <<<\"\$out\" && [ \$(git tag | wc -l | tr -d ' ') = 1 ]"
pc b "fix: a small thing"
check "doctor counts the saves since"                   "says 'version v$(cal 0), 1 save\\(s\\) since' repo_doctor"
rel >/dev/null 2>&1
check "same month twice: the next release is the next patch" "has_tag v$(cal 1)"
pc c "feat: another thing"; pc d "fix: and a fix"; pc d2 "chore: nothing a user notices"
rel >/dev/null 2>&1
check "a feat still drafts its entry under Added, and the version is the next patch" "has_tag v$(cal 2) && [ \"\$(entry $(cal 2))\" = \"\$(printf '### Added\\n- another thing\\n\\n### Fixed\\n- and a fix')\" ]"
pc e "feat(api)!: a breaking change"
rel >/dev/null 2>&1
check "a breaking change no longer moves the version: it is the next patch" "has_tag v$(cal 3) && ! has_tag v$(cal 4)"
check "and a scoped, breaking commit is drafted as one, its scope read" "[ \"\$(entry $(cal 3))\" = \"\$(printf '### Added\\n- **Breaking:** a breaking change')\" ]"
pc f "fix: needed"; printf 'x\n' >> README.md
out=$(just release 2>&1); rc=$?
check "unsaved work: refused, and nothing changes"      "[ $rc -ne 0 ] && grep -q 'there is work not saved yet' <<<\"\$out\" && ! has_tag v$(cal 4)"
git checkout -q -- README.md
out=$(rel major 2>&1)
check "major means the next CalVer too, and says so"     "has_tag v$(cal 4) && grep -q 'patch, minor and major all mean the next CalVer version now: $(cal 4)' <<<\"\$out\""
git commit -q --allow-empty -m "fix: breaking in the body" -m "BREAKING CHANGE: the old way is gone" --no-verify
rel >/dev/null 2>&1
check "a breaking change in the body is still only the next patch" "has_tag v$(cal 5)"
# What a person wrote under Unreleased is the entry, and an empty one is left.
# A commit their words do not carry is offered under its heading first, and a
# line they deleted after it was offered is not offered again (spec 022).
pc g "fix: one more"; pc g2 "feat: a new screen"
perl -0pi -e 's/## \[Unreleased\]\n/## [Unreleased]\n\n### Fixed\n- Written by a person, for the people who use it.\n/' CHANGELOG.md
git add -A; git commit -qm "docs: the unreleased notes" --no-verify
out=$(just release 2>&1)
check "partial notes: the commits they miss are offered, each under its heading, and nothing is tagged" "! has_tag v$(cal 6) && grep -q 'Not released yet' <<<\"\$out\" && grep -q '^Of these, added from the commits: 2' <<<\"\$out\" && [ \"\$(unrel)\" = \"\$(printf '### Fixed\\n- Written by a person, for the people who use it.\\n- one more\\n\\n### Added\\n- a new screen')\" ]"
perl -ni -e 'print unless /^- one more$/' CHANGELOG.md
git add -A; git commit -qm "docs: not that one" --no-verify
out=$(just release 2>&1)
check "an Unreleased section's text becomes the version's entry, and an empty one is left" "grep -q '^Released v$(cal 6)' <<<\"\$out\" && [ \"\$(entry $(cal 6))\" = \"\$(printf '### Fixed\\n- Written by a person, for the people who use it.\\n\\n### Added\\n- a new screen')\" ] && [ -z \"\$(unrel | tr -d ' \\n')\" ]"
pc g3 "fix: named already"
perl -0pi -e 's/## \[Unreleased\]\n/## [Unreleased]\n\n### Fixed\n- named already, and more\n/' CHANGELOG.md
git add -A; git commit -qm "docs: n" --no-verify
check "notes that carry every commit go at once" "says '^Released v$(cal 7)' just release"
pc g4 "fix: share button"
perl -0pi -e 's/## \[Unreleased\]\n/## [Unreleased]\n\n### Fixed\n- Share button, on every screen\n/' CHANGELOG.md
git add -A; git commit -qm "docs: n" --no-verify
check "and a line the notes carry with a capital letter counts as carried" "says '^Released v$(cal 8)' just release"
# The checks refuse the release commit: nothing is half-released, and the
# notes the person read are kept as they left them.
pc h "fix: refused"
just release >/dev/null 2>&1
cp .git/hooks/pre-commit "$tmp/pv-hook" 2>/dev/null || : > "$tmp/pv-hook"
printf '#!/bin/sh\necho "a check said no"\nexit 1\n' > .git/hooks/pre-commit; chmod +x .git/hooks/pre-commit
before=$(cksum < CHANGELOG.md)
out=$(just release 2>&1); rc=$?
check "a release the checks refuse leaves no tag and no half-written changelog" "[ $rc -ne 0 ] && grep -q 'the checks refused the release commit' <<<\"\$out\" && ! has_tag v$(cal 9) && [ \"\$(cksum < CHANGELOG.md)\" = \"\$before\" ] && [ \"\$(git status --porcelain)\" = ' M CHANGELOG.md' ]"
if [ -s "$tmp/pv-hook" ]; then cp "$tmp/pv-hook" .git/hooks/pre-commit; else rm -f .git/hooks/pre-commit; fi
just release >/dev/null 2>&1
# The tags reach GitHub with the backup, and only when the backup does.
git init -q --bare "$tmp/pv-hub.git" && git remote add origin "$tmp/pv-hub.git" && git push -q origin HEAD >/dev/null 2>&1
git config ai-backbone.publish-on-save true
pc i "feat: goes to GitHub"
out=$(rel 2>&1)
check "with publish-on-save on, the release and its tag reach GitHub" "grep -q -- '-> GitHub, with v$(cal 10)' <<<\"\$out\" && git --git-dir='$tmp/pv-hub.git' rev-parse -q --verify refs/tags/v$(cal 10) >/dev/null"
git tag -a marker-1 -m marker
echo carried >> f-carry.txt
just save "fix: a save carries a tag along" >/dev/null 2>&1
check "and a save that reaches GitHub carries a tag along" "git --git-dir='$tmp/pv-hub.git' rev-parse -q --verify refs/tags/marker-1 >/dev/null"
pv_back=$(git symbolic-ref --short HEAD)
git checkout -q -b delegate/2026-01-01-pv
echo worker >> f-carry.txt
out=$(just save "fix: a worker's save" 2>&1)
check "a save on a delegate branch stays here, publish-on-save or not" "grep -q 'not sent to GitHub: a delegate branch' <<<\"\$out\" && ! git --git-dir='$tmp/pv-hub.git' rev-parse -q --verify refs/heads/delegate/2026-01-01-pv >/dev/null"
out=$(just publish 2>&1) && pv_rc=0 || pv_rc=$?
check "and publish refuses a delegate branch" "[ \$pv_rc -ne 0 ] && grep -q 'is a delegate branch' <<<\"\$out\" && ! git --git-dir='$tmp/pv-hub.git' rev-parse -q --verify refs/heads/delegate/2026-01-01-pv >/dev/null"
git checkout -q "$pv_back" && git branch -q -D delegate/2026-01-01-pv
git config ai-backbone.publish-on-save false
pc j "fix: stays here"
rel >/dev/null 2>&1
check "with it off, the release stays on this machine" "has_tag v$(cal 11) && ! git --git-dir='$tmp/pv-hub.git' rev-parse -q --verify refs/tags/v$(cal 11) >/dev/null"
# The Rust layer writes the version where cargo reads it. A stand-in cargo:
# the release commit's lint would otherwise build.
mkdir -p "$tmp/pv-bin" && printf '#!/bin/sh\nexit 0\n' > "$tmp/pv-bin/cargo" && chmod +x "$tmp/pv-bin/cargo"
cp "$root/.ai-backbone/examples/stack-rust.just" stack.just
printf '[workspace]\nmembers = []\n\n[workspace.package]\nversion = "0.1.0"\nedition = "2024"\n\n[package]\nname = "pv"\nversion.workspace = true\n' > Cargo.toml
git add -A; git commit -qm "feat: a Rust workspace" --no-verify
PATH="$tmp/pv-bin:$PATH" rel >/dev/null 2>&1
check "the Rust layer writes the version into [workspace.package]" "has_tag v$(cal 12) && grep -qx 'version = \"$(cal 12)\"' Cargo.toml && grep -qx 'version.workspace = true' Cargo.toml && git show v$(cal 12):Cargo.toml > '$tmp/pv-c' && grep -qx 'version = \"$(cal 12)\"' '$tmp/pv-c'"
printf '[package]\nname = "pv"\nversion = "0.1.0"\nedition = "2024"\n' > Cargo.toml
git add -A; git commit -qm "fix: one crate" --no-verify
PATH="$tmp/pv-bin:$PATH" rel >/dev/null 2>&1
check "and into [package] when there is no workspace version"  "has_tag v$(cal 13) && grep -qx 'version = \"$(cal 13)\"' Cargo.toml"
check "the backbone's own versions are not this recipe's"      "says 'cut by hand' just -f '$root/Justfile' -d '$root' release"
# The notes a person reads are the notes released (spec 022).
rl() { PATH="$tmp/pv-bin:$PATH" just release "$@"; }
pc k "fix: thrown away"
rl >/dev/null 2>&1; git checkout -q -- CHANGELOG.md
out=$(rl 2>&1)
check "a draft thrown away unread is offered once more" "! has_tag v$(cal 14) && grep -q '^Not released yet' <<<\"\$out\" && [ \"\$(unrel)\" = \"\$(printf '### Fixed\\n- thrown away')\" ]"
rl >/dev/null 2>&1
pc l "fix: cache"; pc l2 "feat!: share menu"
perl -0pi -e 's/## \[Unreleased\]\n/## [Unreleased]\n\n### Fixed\n- fixes a shared cache layer\n\n### Added\n- share menu\n/' CHANGELOG.md
git add -A; git commit -qm "docs: n" --no-verify
out=$(rl 2>&1)
check "a short subject inside a longer line, and a breaking one the notes do not call breaking, are offered" "has_tag v$(cal 14) && ! has_tag v$(cal 15) && grep -q '^Of these, added from the commits: 2' <<<\"\$out\" && grep -qx '  - cache' <<<\"\$out\" && grep -qx '  - \*\*Breaking:\*\* share menu' <<<\"\$out\""
rl >/dev/null 2>&1
perl -ni -e 'print unless /^## \[Unreleased\]/' CHANGELOG.md
git add -A; git commit -qm "docs: no heading" --no-verify
pc m "fix: no heading"
rl >/dev/null 2>&1
check "a changelog with no [Unreleased] gets one, above the versions, once" "has_tag v$(cal 15) && ! has_tag v$(cal 16) && [ \$(grep -ci '^## \\[unreleased\\]' CHANGELOG.md) -eq 1 ] && [ \"\$(grep -m1 '^## ' CHANGELOG.md)\" = '## [Unreleased]' ] && [ \"\$(unrel)\" = \"\$(printf '### Fixed\\n- no heading')\" ]"
rl >/dev/null 2>&1
pc n "fix: small letters"
perl -0pi -e 's/## \[Unreleased\]\n/## [unreleased]\n\n### Fixed\n- small letters\n/' CHANGELOG.md
git add -A; git commit -qm "docs: small letters" --no-verify
out=$(rl 2>&1)
check "an [unreleased] in small letters is the same section" "grep -q '^Released v$(cal 17)' <<<\"\$out\" && [ \$(grep -ci '^## \\[unreleased\\]' CHANGELOG.md) -eq 1 ] && [ \"\$(entry $(cal 17))\" = \"\$(printf '### Fixed\\n- small letters')\" ]"
pc o "fix: windows endings"
perl -0pi -e 's/## \[Unreleased\]\n/## [Unreleased]\n\n### Fixed\n- windows endings\n/; s/\n/\r\n/g' CHANGELOG.md
git add -A; git commit -qm "docs: n" --no-verify
out=$(rl 2>&1)
check "a changelog saved with CRLF is read as written, and written back with LF" "grep -q '^Released v$(cal 18)' <<<\"\$out\" && [ \"\$(entry $(cal 18))\" = \"\$(printf '### Fixed\\n- windows endings')\" ] && [ -z \"\$(tr -cd '\\r' < CHANGELOG.md)\" ]"
# A subject with letters outside ASCII was drafted as mojibake: perl wrote out
# as UTF-8 the bytes it had read without decoding them (spec 026).
pc p "fix: 'Amiral Battı' opens again"
out=$(rl 2>&1)
check "a draft keeps a subject's own letters" "grep -qx \"  - 'Amiral Battı' opens again\" <<<\"\$out\" && [ \"\$(unrel)\" = \"\$(printf \"### Fixed\\n- 'Amiral Battı' opens again\")\" ]"
# The layer's _set-version lands in the release commit, beside the changelog
# and the annotated tag (spec 016, still the question in the backlog).
rv="$tmp/rv"
( cd "$root" && just new-project "$rv" ) >/dev/null 2>&1
cd "$rv" || exit 1
printf '%s\n' '[positional-arguments]' '_set-version version:' '    #!/usr/bin/env bash' '    set -euo pipefail' '    printf "%s\n" "$1" > VERSION' > stack.just
git add -A && git commit -qm "feat: a versioned thing" --no-verify
just release >/dev/null 2>&1
out=$(just release 2>&1)
check "the release commit carries the version the layer set, under an annotated tag" "grep -q '^Released v$(cal 0)' <<<\"\$out\" && [ \"\$(cat VERSION)\" = $(cal 0) ] && [ \"\$(git show HEAD:VERSION)\" = $(cal 0) ] && [ \"\$(git cat-file -t v$(cal 0))\" = tag ] && grep -q '^## \\[$(cal 0)\\]' CHANGELOG.md"
# Spec 037: just release refuses while the commit's Windows run is red,
# running or none, and says which. A project with no windows.yml is not asked
# (every release above). The stand-in gh is the same shape as the gate's.
wr="$tmp/winrel"; wgh="$tmp/winrel-gh"; mkdir -p "$wgh"
cat > "$wgh/gh" <<'EOF'
#!/bin/sh
case "$*" in
  *windows.yml*) printf '%s\n' "${FAKE_WINDOWS:-}"; exit 0 ;;
esac
jobs="${FAKE_JOBS:-}"
log="${FAKE_LOG:-}"
winid=$(printf '%s' "${FAKE_WINDOWS:-}" | cut -f1)
if [ -n "$winid" ]; then
  for a in "$@"; do
    if [ "$a" = "$winid" ]; then jobs="${FAKE_WIN_JOBS:-$jobs}"; log="${FAKE_WIN_LOG:-$log}"; break; fi
  done
fi
case "$*" in
  *"--json jobs"*) printf '%s\n' "$jobs" | tr '|' '\n' ;;
  *"--log-failed"*) printf '%s\n' "$log" | tr '|' '\n' ;;
esac
EOF
chmod +x "$wgh/gh"
( cd "$root" && just new-project "$wr" ) >/dev/null 2>&1
cd "$wr" || exit 1
mkdir -p .github/workflows
printf 'name: windows\non:\n  push:\n    branches: [cloud]\n' > .github/workflows/windows.yml
printf 'x\n' > app.txt
git add -A && git commit -qm "feat: needs windows" --no-verify
just release >/dev/null 2>&1
wrel() { PATH="$wgh:$PATH" FAKE_WINDOWS="${1:-}" FAKE_WIN_JOBS="${2:-}" FAKE_WIN_LOG="${3:-}" just release; }
wr_has() { git rev-parse -q --verify "refs/tags/$1" >/dev/null; }
check "release refuses when the windows run is none" "! wrel && says 'Not released: Windows is none' wrel && ! wr_has v$(cal 0)"
check "release refuses when the windows run is running" "! wrel $'88\tin_progress\t' && says 'Not released: Windows is running' wrel $'88\tin_progress\t' && ! wr_has v$(cal 0)"
WJOBS=$'4\tsuite (windows-latest)\tfailure'
WLOG=""
for n in one two three four five six; do
  WLOG="${WLOG:+$WLOG|}suite (windows-latest)"$'\t'"step"$'\t'"t   FAIL  $n"
done
out=$(wrel $'88\tcompleted\tfailure' "$WJOBS" "$WLOG" 2>&1); rc=$?
check "release refuses a red windows run and names at most five FAIL names" "[ $rc -ne 0 ] && grep -q 'Not released: Windows is red: suite (windows-latest) failure FAIL: one;two;three;four;five;' <<<\"\$out\" && ! grep -q 'six' <<<\"\$out\" && ! wr_has v$(cal 0)"
out=$(wrel $'88\tcompleted\tsuccess' 2>&1)
check "release tags when the windows run is green" "grep -q '^Released v$(cal 0)' <<<\"\$out\" && wr_has v$(cal 0)"
# A last tag from another month, and an old SemVer tag, both start this month
# at YY.M.0; a tag already there refuses the release (spec 039).
mo="$tmp/mo"
( cd "$root" && just new-project "$mo" ) >/dev/null 2>&1
cd "$mo" || exit 1
printf 'x\n' > a.txt; git add -A && git commit -qm "feat: a thing" --no-verify
mo_now=$((10#$(date +%m))); mo_yy=$(date +%y)
if [ "$mo_now" -eq 1 ]; then mo_py=$((10#$mo_yy - 1)); mo_pm=12; else mo_py=$mo_yy; mo_pm=$((mo_now - 1)); fi
git tag "v$mo_py.$mo_pm.7"
printf 'y\n' >> a.txt; git add -A && git commit -qm "fix: after the old month" --no-verify
rel >/dev/null 2>&1
check "a last tag from another month starts this month at .0" "has_tag v$(cal 0) && ! has_tag v$mo_py.$mo_pm.8"
sv="$tmp/semver"
( cd "$root" && just new-project "$sv" ) >/dev/null 2>&1
cd "$sv" || exit 1
printf 'x\n' > a.txt; git add -A && git commit -qm "feat: a thing" --no-verify
git tag v0.4.2
printf 'y\n' >> a.txt; git add -A && git commit -qm "fix: after the old number" --no-verify
rel >/dev/null 2>&1
check "a project whose last tag is v0.4.2 cuts this month's YY.M.0, not 0.4.3" "has_tag v$(cal 0) && ! has_tag v0.4.3"
dup="$tmp/dup"
( cd "$root" && just new-project "$dup" ) >/dev/null 2>&1
cd "$dup" || exit 1
printf 'x\n' > a.txt; git add -A && git commit -qm "feat: a thing" --no-verify
git tag v99.12.7; git tag "v$(cal 0)"
printf 'y\n' >> a.txt; git add -A && git commit -qm "fix: after the tags" --no-verify
out=$(just release 2>&1); rc=$?
check "a tag that is already there refuses the release" "[ $rc -ne 0 ] && grep -q 'the tag v$(cal 0) is there already' <<<\"\$out\""
cd "$tmp" || exit 1

fi
if lane_wants b26; then
section "the backlog of 2026-10-06 (spec 026)"
s26="$tmp/s26"
( cd "$root" && just new-project "$s26" ) >/dev/null 2>&1
cd "$s26" || exit 1
check "a new project's AGENTS.md has a slot for a managing repository" "grep -qx '| managed_by | none |' AGENTS.md && grep -q 'just project-note' AGENTS.md"
# A save of named paths takes those and names what it left.
printf 'a\n' > a.txt; printf 'b\n' > b.txt
out=$(just save "docs: only a" a.txt 2>&1)
check "save with a path saves that path alone, and names what it left" "[ \"\$(git show --name-only --format= HEAD)\" = a.txt ] && grep -q 'not in this save, still unsaved: 1 file' <<<\"\$out\" && grep -q 'b.txt' <<<\"\$out\""
check "a path that is not there is refused, and nothing is saved" "! just save 'docs: x' nothere.txt && says 'nothere.txt is not in this project' just save 'docs: x' nothere.txt && [ \"\$(git log -1 --format=%s)\" = 'docs: only a' ]"
check "without paths a save still takes everything" "just save 'docs: the rest' >/dev/null 2>&1 && [ -z \"\$(git status --porcelain)\" ]"
mkdir -p docs/sub; printf 'c\n' > docs/sub/c.txt
check "a path is read from the folder just was typed in" "( cd docs/sub && just save 'docs: c' c.txt >/dev/null 2>&1 ) && [ \"\$(git show --name-only --format= HEAD)\" = docs/sub/c.txt ]"
git mv a.txt a2.txt >/dev/null
check "a renamed file is saved by its old and new names" "just save 'docs: rename' a.txt a2.txt >/dev/null 2>&1 && [ -z \"\$(git status --porcelain)\" ] && [ -f a2.txt ]"
# A done spec whose Acceptance list still has an open box is named; one
# marked [~] with its reason is not.
mkdir -p docs/specs
printf -- '---\nstatus: done\n---\n\n# 001 — x\n\n## Acceptance\n\n- [x] one\n- [ ] two\n\n## Tasks\n\n- [x] t\n' > docs/specs/001-x.md
check "session-start names a done spec with an acceptance box open" "says '^Spec 001-x [(]done[)]: 1 acceptance line not ticked' just session-start"
perl -pi -e 's/^- \[ \] two/- [~] two, not yet: why/' docs/specs/001-x.md
check "and a [~] line is named as waiting for the owner" "says '^Spec 001-x [(]done[)]: 1 acceptance line waiting for the owner. Next: two, not yet: why' just session-start"
# A skill's folder and its name: differ.
mkdir -p .agents/skills/zz && printf -- '---\nname: "Zed"\ndescription: x\n---\n' > .agents/skills/zz/SKILL.md
check "sync-rules and doctor name a skill whose folder and name: differ" "says 'agents/skills/zz says name: Zed' just sync-rules && says 'skill folder .agents/skills/zz says name: Zed' just doctor && [ \"\$(just _skill-names)\" = 'zz Zed' ]"
rm -rf .agents/skills/zz .claude/skills/zz
check "and nothing when they agree" "[ -z \"\$(just _skill-names)\" ] && ! says 'says name:' just doctor"
# doctor: a tool older than its pin, and a language with no watch list.
mkdir -p "$tmp/s26bin"; printf '#!/bin/sh\necho "uv 0.8.17"\n' > "$tmp/s26bin/uv"; chmod +x "$tmp/s26bin/uv"
printf '[[watch]]\nname = "uv"\nsource = "github:astral-sh/uv"\npin = "0.12.19"\n' > docs/upstream.toml
check "doctor says when a tool is older than its pin" "says 'warn  uv 0.8.17 is older than its pin 0.12.19 in docs/upstream.toml -> just tools-update' env PATH=\"$tmp/s26bin:\$PATH\" just doctor"
printf '[[watch]]\nname = "uv"\nsource = "github:astral-sh/uv"\npin = "0.8.0"\n' > docs/upstream.toml
check "and nothing when it is the pin or newer" "! says 'older than its pin' env PATH=\"$tmp/s26bin:\$PATH\" just doctor"
mkdir -p "$tmp/dock"
printf '%s\n' '{"credsStore": "fast"}' > "$tmp/dock/config.json"
printf '#!/bin/sh\nexit 0\n' > "$tmp/dock/docker-credential-fast"; chmod +x "$tmp/dock/docker-credential-fast"
check "a Docker credential helper that answers is not a warning" "! says 'credential helper|credsStore' env DOCKER_CONFIG='$tmp/dock' PATH=\"$tmp/dock:\$PATH\" just doctor"
printf '%s\n' '{"credsStore": "slow"}' > "$tmp/dock/config.json"
printf '#!/bin/sh\nsleep 30\n' > "$tmp/dock/docker-credential-slow"; chmod +x "$tmp/dock/docker-credential-slow"
check "a Docker credential helper that does not answer is named within a few seconds" "says 'docker-credential-slow did not answer within 3 seconds' env DOCKER_CONFIG='$tmp/dock' PATH=\"$tmp/dock:\$PATH\" just doctor"
printf '%s\n' '{"credsStore": "gone"}' > "$tmp/dock/config.json"
check "a Docker credsStore whose helper is missing is named" "says 'docker-credential-gone is not on PATH' env DOCKER_CONFIG='$tmp/dock' PATH=\"$tmp/dock:\$PATH\" just doctor"
rm -f docs/upstream.toml; printf '# a layer\n' > stack.just
check "doctor says when a project with a language has no watch list" "says 'a language layer and no watch list.*just upstream-init' just doctor"
just upstream-init >/dev/null 2>&1
check "and nothing once it has one" "! says 'no watch list' just doctor"
rm -f stack.just
# just projects: what each project's last weekly check found behind, from its cache.
pj="$tmp/pj"; mkdir -p "$pj/bb/.ai-backbone" "$pj/app/.ai-backbone" "$pj/app/docs"
cp "$root/.ai-backbone/projects.sh" "$pj/bb/.ai-backbone/"; printf '# version 9.9.9\n' > "$pj/bb/.ai-backbone/core.just"; cp "$pj/bb/.ai-backbone/core.just" "$pj/app/.ai-backbone/"
git -C "$pj/app" init -q; : > "$pj/app/docs/upstream.toml"
printf '{"behind": ["flutter sdk", "prek"], "moved": [], "released": {}}' > "$pj/app/.git/upstream-cache.json"
check "just projects names what is newer upstream in each project" "says '^  app +9.9.9 .* 2 newer +.*newer upstream: flutter sdk, prek' bash '$pj/bb/.ai-backbone/projects.sh'"
# Outside $pj: projects.sh already looks one and two folders down from the
# backbone, so a root placed there would be counted before the local list.
mkdir -p "$tmp/extra/side/.ai-backbone" "$tmp/extra/rustp/.ai-backbone"
printf '# version 1.0.0\n' > "$tmp/extra/side/.ai-backbone/core.just"
printf '# version 1.0.0\n' > "$tmp/extra/rustp/.ai-backbone/core.just"
printf '_build-info:\n    @echo dir x\n    @echo cargo\n' > "$tmp/extra/rustp/stack.just"
printf '%s\n%s\n%s\n' "$tmp/extra/side" "$pj/nowhere" "$pj/app" > "$tmp/roots.txt"
check "local roots add a project once, and a missing root is said" "o=\$(AI_BACKBONE_PROJECT_ROOTS='$tmp/roots.txt' bash '$pj/bb/.ai-backbone/projects.sh'); grep -q '^  side ' <<<\"\$o\" && grep -q 'missing root: $pj/nowhere' <<<\"\$o\" && [ \$(grep -c '^  app ' <<<\"\$o\") -eq 1 ] && grep -q '^2 project' <<<\"\$o\""
check "a local root's name is one the backbone refuses to commit" "says '^side$' env AI_BACKBONE_PROJECT_ROOTS='$tmp/roots.txt' just _sibling-names '$root'"
printf '%s\n' "$tmp/extra/rustp" > "$tmp/rust-roots.txt"
check "the rust project list includes a local root once" "o=\$(env AI_BACKBONE_PROJECTS='$tmp/no-projects' AI_BACKBONE_PROJECT_ROOTS='$tmp/rust-roots.txt' just _rust-projects); [ \$(grep -c '/rustp$' <<<\"\$o\") -eq 1 ]"
# routine-install on a Mac refuses a project in Desktop, Documents or Downloads,
# which launchd may not read; routine-status shows how the last run ended.
dh="$tmp/dhome"; mkdir -p "$dh/Desktop" "$tmp/mac"
printf '#!/bin/sh\necho Darwin\n' > "$tmp/mac/uname"; chmod +x "$tmp/mac/uname"
( cd "$root" && just new-project "$dh/Desktop/deskproj" ) >/dev/null 2>&1
check "routine-install refuses a project inside ~/Desktop on a Mac, and says why" "says 'inside ~/Desktop, and macOS does not let a scheduled job' bash -c 'cd \"$dh/Desktop/deskproj\" && HOME=\"$dh\" PATH=\"$tmp/mac:\$PATH\" just routine-install' && [ ! -d '$dh/Library/LaunchAgents' ]"
rl26="ai-backbone.routine.$(just _slug s26)"; mkdir -p "$dh/Library/LaunchAgents" "$tmp/mac26" brain/05-files
sed -e "s|LABEL|$rl26|" -e 's|WEEKDAY|0|' -e 's|HOUR|8|' -e 's|MINUTE|47|' .ai-backbone/templates/routine.plist > "$dh/Library/LaunchAgents/$rl26.plist"
printf '#!/bin/sh\nprintf "%%s\\t%%s\\t%%s\\n" 123 78 %s\n' "$rl26" > "$tmp/mac26/launchctl"; chmod +x "$tmp/mac26/launchctl"
printf '/bin/sh: ./routine.sh: Operation not permitted\n' > brain/05-files/routine.log
check "routine-status names a last run that did not end at 0, and a macOS refusal" "says 'last run ended with status 78' env HOME='$dh' PATH='$tmp/mac26:'\"\$PATH\" just routine-status && says 'refused by macOS' env HOME='$dh' PATH='$tmp/mac26:'\"\$PATH\" just routine-status"
# CI/CD for a project with a Dockerfile.
check "the ship notes say to publish first, and that a tree comparison after main moves is a false alarm" "grep -q 'must publish' '$root/.ai-backbone/examples/README.md' && grep -q 'false alarm' '$root/.ai-backbone/examples/README.md' && grep -q 'must publish first' '$root/docs/01-getting-started.md' && grep -q 'false alarm' '$root/docs/01-getting-started.md'"
check "ci-init image needs a Dockerfile" "! just ci-init image && says 'No Dockerfile' just ci-init image && [ ! -e .github/workflows/image.yml ]"
printf 'FROM scratch\n' > Dockerfile
out=$(just ci-init image 2>&1)
check "ci-init image writes the image workflow and the update bot" "grep -q 'added   .github/workflows/image.yml' <<<\"\$out\" && cmp -s .github/workflows/image.yml '$root/.ai-backbone/examples/image.yml' && grep -q 'docker-compose' .github/dependabot.yml && grep -q 'named checks, and there is none yet' <<<\"\$out\""
check "the workflow it wrote passes ci-check, and builds only after green checks on a push to main" "just ci-check >/dev/null 2>&1 && grep -q 'workflows: \\[checks\\]' .github/workflows/image.yml && grep -q \"conclusion == 'success'\" .github/workflows/image.yml && grep -q 'packages: write' .github/workflows/image.yml && ! grep -q ':latest' .github/workflows/image.yml"
check "run again it says the copy is the backbone's" "says 'ok      .github/workflows/image.yml is the backbone' just ci-init image"
printf '# edited here\n' >> .github/workflows/image.yml
check "and says when the copy differs, without overwriting it" "says 'differs .github/workflows/image.yml' just ci-init image && grep -q '^# edited here' .github/workflows/image.yml"
check "and the checks it waits for can still be added after it" "just ci-init generic >/dev/null 2>&1; [ -f .github/workflows/checks.yml ] && grep -q '^name: checks' .github/workflows/checks.yml"
# A project that never goes to GitHub, and one that keeps no second copy of
# brain/: both said per project, in its own git config (spec 026).
git config ai-backbone.local-only true
check "a local-only project refuses publish, publish-on-save and ci-init" "says 'Not sent: this project is local-only' just publish && ! just publish && says 'local-only' just publish-on-save on && says 'no GitHub to run checks on' just ci-init && ! just ci-init"
check "and session-start does not ask for a GitHub address" "! says 'GitHub: no address yet' just session-start && says 'ok    local-only' just doctor"
just hooks-install >/dev/null 2>&1
git init -q --bare "$tmp/s26-remote.git"; git remote add origin "$tmp/s26-remote.git"
check "hooks-install adds a pre-push hook that refuses every push" "! git push -q origin HEAD 2>/dev/null && says 'Not pushed: this project is local-only' git push origin HEAD && says 'local-only, and it has a GitHub address' just doctor"
git config --unset ai-backbone.local-only
check "and that hook lets pushes through once the setting is off" "git push -q origin HEAD 2>/dev/null"
git remote remove origin
mkdir -p "$tmp/s26-vault"; git config --global ai-backbone.vault-copy "$tmp/s26-vault"
git config ai-backbone.vault-copy off
check "a project can turn its vault copy off, and doctor and session-end say so" "says 'turned it off' just doctor && says 'keeps no second copy' just session-end && [ ! -d '$tmp/s26-vault/s26' ]"
git config ai-backbone.vault-copy "$tmp/s26-own"; mkdir -p "$tmp/s26-own"
# Where the copy goes is asked of _vault-dest, so a machine without rsync checks
# it too; by its end, since git on Windows hands the folder back as C:/...
check "and a place set in the project comes before the machine's" "says '/s26-own/s26\$' just _vault-dest"
git config --unset ai-backbone.vault-copy; git config --global --unset ai-backbone.vault-copy

# After a merge, union can bring a removed backlog line back, or twin an edited one.
bm="$tmp/bm"; mkdir -p "$bm/docs"; cd "$bm" || exit 1
# As the backbone's own: LF on every machine (Windows wrote CRLF and the edit
# below never matched), and the import by a path just on Windows can read.
git init -q -b cloud; printf '* text=auto eol=lf\ndocs/backlog.md merge=union\n' > .gitattributes; printf "import '%s/.ai-backbone/core.just'\n" "$rootw" > Justfile
printf '# Backlog\n\n- [ ] 2026-10-01, n-aaaaaa: first\n- [ ] 2026-10-02, n-bbbbbb: second\n- [ ] 2026-10-03, n-cccccc: third\n' > docs/backlog.md
git add -A; git commit -qm "docs: base" --no-verify
git checkout -qb side; printf -- '- [ ] 2026-10-06, n-dddddd: new note\n' >> docs/backlog.md; git commit -qam "docs: note" --no-verify
git checkout -q cloud; perl -ni -e 'print unless /n-cccccc/; ' docs/backlog.md; perl -pi -e 's/second$/second blocked: x/' docs/backlog.md; git commit -qam "docs: built" --no-verify
git merge -q --no-edit side >/dev/null 2>&1
check "the union merge brought the removed line back and twinned the edited one" "grep -q n-cccccc docs/backlog.md && [ \$(grep -c n-bbbbbb docs/backlog.md) -eq 2 ]"
out=$(just _backlog-mend 2>&1)
check "_backlog-mend takes out both, keeps the note and the edit, and commits only that" "! grep -q n-cccccc docs/backlog.md && [ \$(grep -c n-bbbbbb docs/backlog.md) -eq 1 ] && grep -q 'second blocked: x' docs/backlog.md && grep -q n-dddddd docs/backlog.md && [ \"\$(git log -1 --format=%s)\" = 'docs: backlog mended after a merge' ] && grep -q 'brought back or doubled 2 line' <<<\"\$out\""
check "and says nothing when there is nothing to mend" "[ -z \"\$(just _backlog-mend 2>&1)\" ]"
cd "$tmp" || exit 1

# ── spec 027: the backlog of 2026-10-10 ──
fi
if lane_wants b27; then
section "the backlog of 2026-10-10 (spec 027)"
# A Hugging Face model pinned by its commit: the commits above the pin are newer.
# From a fixture, with every other address refused, the whole script running.
hf="$tmp/hf"; mkdir -p "$hf/docs" "$hf/.git"
printf 'model: d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3\nold: b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1\n' > "$hf/docs/pins.txt"
printf '[[watch]]\nname = "model"\nsource = "hf:org/model"\npin = "b2c3d4e"\npinned_in = "docs/pins.txt"\n\n[[watch]]\nname = "newest"\nsource = "hf:org/model"\npin = "d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3"\npinned_in = "docs/pins.txt"\n\n[[watch]]\nname = "lost"\nsource = "hf:org/model"\npin = "0000000"\n\n[[watch]]\nname = "moved"\nsource = "hf:org/model"\npin = "a1b2c3d"\npinned_in = "docs/pins.txt"\n' > "$hf/docs/upstream.toml"
hfu() { ( cd "$hf" && "$py" -c "import importlib.util as i, json, sys; s=i.spec_from_file_location('u', '$rootw/.ai-backbone/upstream.py'); u=i.module_from_spec(s); s.loader.exec_module(u); u.OFFLINE=False; u.fetch_json=lambda url, headers=None: json.load(open('$rootw/.ai-backbone/fixtures/hf-commits.json')) if url == 'https://huggingface.co/api/models/org/model/commits/main' else sys.exit('asked ' + url); sys.exit(u.main())" "$@" ); }
check "hf: a pin two commits behind is 2 newer, dated by its own commit, held by the file" "says '^  model +b2c3d4e +2026-07-01 +d4e5f6a7b8c9 +2 newer +ok\$' hfu"
check "a pin at the newest commit, written in full, is current" "says '^  newest +d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3 +2026-09-30 +— +current +ok\$' hfu"
check "a commit the model does not list is no answer, and says why" "says '^  lost: lists no commit 0000000 among its last 4; the newest is d4e5f6a7b8c9' hfu"
check "a commit the pin file no longer holds is MOVED" "says '^  moved .* MOVED\$' hfu"
check "and one model read prints the newer commits with their titles" "says '^-- d4e5f6a7b8c9  2026-09-30  https://huggingface.co/org/model/commit/d4e5' hfu model && says '^Fix the chat template' hfu model"
check "the template names the Hugging Face source" "grep -q 'hf:owner/name' '$root/.ai-backbone/templates/upstream.toml'"
# Fifty commits a page: a pin older than the first page is found on the next.
hfp() { "$py" -c "import importlib.util as i, sys, urllib.error; s=i.spec_from_file_location('u', '$rootw/.ai-backbone/upstream.py'); u=i.module_from_spec(s); s.loader.exec_module(u); asked=[]
def page(url, headers=None):
    asked.append(url)
    if 'gated' in url: raise urllib.error.HTTPError(url, 401, 'Unauthorized', {}, None)
    ids = range(100, 50, -1) if '?p=1' not in url else range(50, 47, -1)
    return [{'id': '%040x' % n, 'date': '2026-01-01T00:00:00.000Z', 'title': 't'} for n in ids]
u.fetch_json = page
$1"; }
check "a pin past the first page of fifty is found on the next, and no page after it is asked" "hfp \"r = u.from_hf('o/m', '%040x' % 49); ahead, at, why = u.commits_after({'pin': '%040x' % 49}, r); sys.exit(0 if len(ahead) == 51 and not why and len(asked) == 2 else 1)\""
check "a gated model says so and names HF_TOKEN" "says 'gated or private; set HF_TOKEN' hfp \"u.from_hf('o/gated')\""
# A repository that publishes no release is watched by the commits on its
# default branch (spec 035). The request names no branch. From stand-in pages,
# with every other address refused, and gh never called.
cat > "$tmp/ghcommit.py" <<'PY'
import importlib.util
import os
import sys
from pathlib import Path

root, mode, base = sys.argv[1:]
os.environ.pop("AI_BACKBONE_OFFLINE", None)
spec = importlib.util.spec_from_file_location("u", str(Path(root) / ".ai-backbone" / "upstream.py"))
u = importlib.util.module_from_spec(spec)
spec.loader.exec_module(u)
u.OFFLINE = False
u.shutil_which = lambda name: None
asked = []

def row(n):
    sha = "%040x" % n
    return {"sha": sha, "html_url": "https://github.com/o/r/commit/" + sha,
            "commit": {"message": "t", "committer": {"date": "2026-01-01T00:00:00Z"}}}

def fake(url, headers=None):
    asked.append(url)
    prefix = "https://api.github.com/repos/o/r/commits?per_page=30&page="
    if not url.startswith(prefix):
        raise SystemExit("asked " + url)
    page = int(url[len(prefix):])
    if mode == "page":
        if page == 1:
            return [row(n) for n in range(100, 70, -1)]
        if page == 2:
            return [row(n) for n in range(70, 40, -1)]
        return []
    if page == 1:
        return [
            {"sha": "a" * 40, "html_url": "https://github.com/o/r/commit/" + "a" * 40,
             "commit": {"message": "Ask only\n\nA flag.", "committer": {"date": "2026-10-20T08:00:00Z"}}},
            {"sha": "b" * 40, "html_url": "https://github.com/o/r/commit/" + "b" * 40,
             "commit": {"message": "Start", "committer": {"date": "2026-10-01T08:00:00Z"}}},
        ]
    return []

u.fetch_json = fake

def fail(msg):
    print(msg, file=sys.stderr)
    raise SystemExit(1)

if mode == "page":
    pin = "%040x" % 41
    rows = u.from_ghcommit("o/r", pin)
    ahead, _at, why = u.commits_after({"pin": pin}, rows)
    bad = [url for url in asked if "sha=" in url or "/commits/" in url]
    if why or len(ahead) != 59 or len(asked) != 2 or bad:
        fail(f"ahead={len(ahead)} why={why} asked={asked}")
else:
    project = Path(base) / mode
    os.chdir(project)
    # main() reads sys.argv. This file's own arguments are the fixture, not a
    # name on the watch list.
    sys.argv = ["upstream.py", "--freshness"] if mode == "fresh" else ["upstream.py"]
    sys.exit(u.main())
PY
mkdir -p "$tmp/ghc/table/docs" "$tmp/ghc/table/.git" "$tmp/ghc/fresh/docs" "$tmp/ghc/fresh/.git"
printf '[[watch]]\nname = "idea"\nkind = "idea"\nsource = "ghcommit:o/r"\npin = "bbbbbbb"\nlook_for = "an ask-only mode"\n\n[[watch]]\nname = "tip"\nkind = "idea"\nsource = "ghcommit:o/r"\npin = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"\nlook_for = "an ask-only mode"\n\n[[watch]]\nname = "lost"\nsource = "ghcommit:o/r"\npin = "0000000"\n' > "$tmp/ghc/table/docs/upstream.toml"
cp "$tmp/ghc/table/docs/upstream.toml" "$tmp/ghc/fresh/docs/upstream.toml"
ghc() { env -u AI_BACKBONE_OFFLINE AI_BACKBONE_UPSTREAM_CACHE="$tmp/ghc-cache-$1" "$py" "$tmp/ghcommit.py" "$rootw" "$1" "$tmp/ghc"; }
check "ghcommit: a pin past the first page is found on the next, and the request names no branch" "ghc page"
check "ghcommit: a pin one commit behind is 1 newer, dated by its own commit" "says '^  idea +bbbbbbb +2026-10-01 +aaaaaaaaaaaa +1 newer +-\$' ghc table"
check "ghcommit: the newest commit, written in full, is current" "says '^  tip +a{40} +2026-10-20 +— +current +-\$' ghc table"
check "ghcommit: a commit the list does not hold is no answer" "says '^  lost: lists no commit 0000000 among its last 2; the newest is aaaaaaaaaaaa\$' ghc table"
check "an idea pinned by commit is to read, never behind" "says 'To read: idea bbbbbbb → aaaaaaaaaaaa [(]an ask-only mode[)]' ghc fresh && says 'Behind: nothing' ghc fresh && ! says 'Behind: idea' ghc fresh"
check "the template names a GitHub commit source" "grep -q 'ghcommit:owner/repo' '$root/.ai-backbone/templates/upstream.toml'"
# Claude Code's agent checkouts are repositories of their own; a save must not take them.
check "a new project ignores Claude Code's agent worktrees" "( cd '$tmp/plain' && git check-ignore -q .claude/worktrees/agent-1/file )"
check "the session skill says what to do when the context fills up" "grep -q '^## When the context fills up' '$root/.agents/skills/session/SKILL.md' && grep -q 'new chat' '$root/.agents/skills/session/SKILL.md' && grep -q 'Do not compact on your own' '$root/.agents/skills/session/SKILL.md'"

# A save runs its checks itself, in the order written, and stops at the first
# that fails: a slow suite below a cheap check that failed never starts.
# Fixers fail on purpose, so their runs repeat until nothing more changes.
if ( cd "$root" && just new-project "$tmp/s27" ) >/dev/null 2>&1; then ok "a project for the save checks"; else bad "a project for the save checks"; fi
cd "$tmp/s27" || exit 1
cat >> .pre-commit-config.yaml <<EOF

  - repo: local
    hooks:
      - id: word
        name: no forbidden word
        entry: bash -c 'if grep -l FORBIDDEN "\$@"; then exit 1; fi' --
        language: system
        files: '\.txt\$'
      - id: slow
        name: slow suite
        entry: bash -c 'touch "$tmp/s27-slow"'
        language: system
        pass_filenames: false
        stages: [pre-commit]
EOF
git add -A >/dev/null 2>&1; git commit -qm "chore: the two checks" --no-verify
s27log=$(git rev-parse --git-path ai-backbone-checks.log)
if [ -n "$(command -v prek)" ] && grep -qs prek "$(git rev-parse --git-path hooks/pre-commit)"; then
  printf 'a  \nFORBIDDEN' > a.txt; rm -f "$tmp/s27-slow"
  out=$(just save "add a" 2>&1); rc=$?
  check "a save whose cheap check fails is refused, and the slow one below it never starts" "[ $rc -ne 0 ] && grep -q 'no forbidden word\.*Failed' <<<\"\$out\" && [ ! -e '$tmp/s27-slow' ] && [ \"\$(git log -1 --format=%s)\" = 'chore: the two checks' ]"
  check "both fixers above it ran, one run each" "[ \"\$(head -1 a.txt)\" = a ] && [ \"\$(tail -c 1 a.txt | od -An -c | tr -d ' ')\" = '\n' ] && grep -q '(checks, run 3)' '$s27log'"
  printf 'a\nfine\n' > a.txt; printf 'b  \nb' > b.txt
  out=$(just save "add a and b" 2>&1); rc=$?
  check "two fixers in a row are fixed and saved in one save, and the slow check ran" "[ $rc -eq 0 ] && [ \"\$(git log -1 --format=%s)\" = 'chore: add a and b' ] && [ -z \"\$(git status --porcelain)\" ] && [ -e '$tmp/s27-slow' ]"
  check "a save says in one line how many checks passed and which had nothing to check" "grep -qE '^  checks: [0-9]+ passed; nothing to check for .*check yaml' <<<\"\$out\" && [ \$(grep -c 'checks:' <<<\"\$out\") -eq 1 ]"
  check "and the log keeps every run of it, the message checks too" "grep -q 'chore: add a and b  (message checks)' '$s27log' && grep -q 'slow suite\.*Passed' '$s27log'"
  echo x >> b.txt
  check "the message checks still refuse a Turkish message" "! just save 'özellik: türkçe' >/dev/null 2>&1 && [ \"\$(git log -1 --format=%s)\" = 'chore: add a and b' ]"
  # A hook of the project's own, kept by prek as <hook>.legacy, still runs: the
  # save goes the old way, through git's hooks, when one is there.
  printf '#!/bin/sh\necho "the project own hook refuses"\nexit 1\n' > "$(git rev-parse --git-path hooks/pre-commit).legacy"; chmod +x "$(git rev-parse --git-path hooks/pre-commit).legacy"
  check "a hook of the project's own still refuses a save" "! says 'Saved|Kaydedildi' just save 'chore: past an own hook' && [ \"\$(git log -1 --format=%s)\" = 'chore: add a and b' ]"
  rm -f "$(git rev-parse --git-path hooks/pre-commit).legacy"
  mv "$(git rev-parse --git-path hooks/pre-commit)" "$tmp/s27-hook"; mv "$(git rev-parse --git-path hooks/commit-msg)" "$tmp/s27-msg"; rm -f "$tmp/s27-slow"
  out=$(just save "without hooks" 2>&1); rc=$?
  check "a project whose hooks are not installed saves as before, with no checks line" "[ $rc -eq 0 ] && [ \"\$(git log -1 --format=%s)\" = 'chore: without hooks' ] && ! grep -q 'checks:' <<<\"\$out\" && [ ! -e '$tmp/s27-slow' ]"
  mv "$tmp/s27-hook" "$(git rev-parse --git-path hooks/pre-commit)"; mv "$tmp/s27-msg" "$(git rev-parse --git-path hooks/commit-msg)"
else
  bad "the save checks need prek and its hooks in the new project"
fi
check "the seed says the checks run in the order written, a slow one last" "grep -q 'stops at the first that' '$root/.ai-backbone/seed/pre-commit-config.yaml' && grep -q 'goes last' '$root/.ai-backbone/seed/pre-commit-config.yaml'"
cd "$tmp" || exit 1

# The build queue. Each waiting build takes a ticket and only the oldest goes;
# one that went holds the turn until its holder ends. Holders here are sleeps
# the suite ends by hand, named through BUILD_WAIT_HOLDER; nothing compiles.
cd "$bo/proj" || exit 1
bq="$AI_BACKBONE_BUILD_QUEUE"; rm -rf "$bq"; : > "$tmp/q-order"
sleep 120 & h1=$!; sleep 120 & h2=$!; sleep 120 & h3=$!
: > "$tmp/q-pids"
waiter() {
  ( bw env BUILD_WAIT_HOLDER="$2" BUILD_WAIT_MINUTES=2 just _build-wait >/dev/null 2>"$tmp/q-err$1"; echo "$1" >> "$tmp/q-order" ) &
  printf '%s\n' "$!" >> "$tmp/q-pids"
}
waiter 1 "$h1"; sleep 2; waiter 2 "$h2"; sleep 2; waiter 3 "$h3"; sleep 3
check "three waiting builds: the first goes at once, the other two wait their turn" "[ \"\$(tr '\n' ' ' < '$tmp/q-order')\" = '1 ' ] && grep -q '^2 other build(s) on this machine came first' '$tmp/q-err3'"
suite_stop "$h1"; sleep 7
check "when the first one's holder ends, the second goes and the third still waits" "[ \"\$(tr '\n' ' ' < '$tmp/q-order')\" = '1 2 ' ]"
suite_stop "$h2"; sleep 7
check "and then the third: one at a time, oldest first" "[ \"\$(tr '\n' ' ' < '$tmp/q-order')\" = '1 2 3 ' ] && grep -q '^Its turn: going on' '$tmp/q-err3'"
suite_stop "$h3"
while IFS= read -r qpid; do suite_wait "$qpid" 20; done < "$tmp/q-pids"
sleep 0 & gone=$!; suite_wait "$gone" 5
printf '%s\n' "$gone" > "$bq/t-0000000001-00000001"
s=$SECONDS; bw env BUILD_WAIT_MINUTES=2 just _build-wait >/dev/null 2>&1; took=$((SECONDS - s))
check "a ticket whose holder is gone holds nobody, and is thrown away" "[ $took -lt 4 ] && [ ! -e '$bq/t-0000000001-00000001' ]"
sleep 120 & hs=$!
printf '%s %s\n' "$hs" "$(( $(date +%s) - 300 ))" > "$bq/t-0000000002-00000002"
s=$SECONDS; bw env BUILD_WAIT_MINUTES=2 just _build-wait >/dev/null 2>&1; took=$((SECONDS - s))
check "a build that went longer ago than the limit holds nobody" "[ $took -lt 4 ]"
sleep 0 & gone=$!; suite_wait "$gone" 5
printf '%s\n' "$hs" > "$bq/t-0000000004-$(printf '%08d' "$gone")"
s=$SECONDS; bw env BUILD_WAIT_MINUTES=2 just _build-wait >/dev/null 2>&1; took=$((SECONDS - s))
check "a ticket still waiting whose waiter is gone holds nobody, though its holder lives" "[ $took -lt 4 ] && [ ! -e '$bq/t-0000000004-$(printf '%08d' "$gone")' ]"
printf '%s %s\n' "$hs" "$(( $(date +%s) - 60 ))" > "$bq/t-0000000005-00000005"
s=$SECONDS; bw env BUILD_WAIT_MINUTES=2 just _build-wait >/dev/null 2>"$tmp/q-err5"; took=$((SECONDS - s))
check "a build that went a minute ago holds the turn no longer once no compiler runs" "[ $took -lt 15 ] && grep -q 'Its turn: going on' '$tmp/q-err5'"
printf '%s %s\n' "$hs" "$(( $(date +%s) - 60 ))" > "$bq/t-0000000007-00000007"
: > "$tmp/q-hold"
( bw env BUILD_WAIT_HOLD=whole BUILD_WAIT_MINUTES=2 just _build-wait >/dev/null 2>"$tmp/q-hold"; echo done >> "$tmp/q-hold" ) &
wh=$!
sleep 4
check "BUILD_WAIT_HOLD=whole keeps a minute-old turn while its holder lives" "kill -0 $wh && ! grep -qx done '$tmp/q-hold'"
suite_stop "$hs"
sleep 8
check "and lets that turn go when the holder ends" "grep -qx done '$tmp/q-hold' && grep -q 'Its turn: going on' '$tmp/q-hold'"
suite_wait "$wh" 15
rm -f "$bq"/t-*
# One limit for the whole wait (spec 032): the queue and a running compiler
# together, not each in full; and the wait names the project that holds the turn.
sleep 120 & hs=$!
printf '%s %s %s\n' "$hs" "$(( $(date +%s) - 5 ))" "/x/other-proj" > "$bq/t-0000000006-00000006"
s=$SECONDS; out=$(bw env PS_BUSY=99 BUILD_WAIT_MINUTES=0.2 just _build-wait 2>"$tmp/q-err6"); took=$((SECONDS - s))
check "behind a turn and a running compiler, the wait is one limit in all, then half the cores" "[ $took -ge 10 ] && [ $took -lt 20 ] && [ \"\$out\" = 'CARGO_BUILD_JOBS=$half' ]"
check "and it names the project that holds the turn" "grep -q 'came first (the turn is other-proj, for under a minute)' '$tmp/q-err6'"
suite_stop "$hs"
rm -f "$bq"/t-*
# Where ps lists parents, a ticket whose holder is this caller, or above it, is
# this build's own (a recipe that waits and then calls another that waits).
if "$REAL_PS" -A -o pid= -o ppid= >/dev/null 2>&1; then
  printf '%s %s\n' "$$" "$(date +%s)" > "$bq/t-0000000003-00000003"
  s=$SECONDS; bw env BUILD_WAIT_MINUTES=2 just _build-wait >/dev/null 2>&1; took=$((SECONDS - s))
  check "a build of this caller's own, above it, does not hold it" "[ $took -lt 4 ]"
  rm -f "$bq"/t-*
fi
cd "$tmp" || exit 1

# Build trimming. A fake cargo folder, its pieces dated by hand: random bytes,
# never zeros, which a file system that compresses keeps in no space at all.
# The cap is given in GB, so a few hundred KB is a small fraction of one.
mkcargo() {
  "$py" - "$1" <<'PY'
import os, sys, time
root = sys.argv[1]
day = 86400
def put(rel, kb, age):
    path = os.path.join(root, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(os.urandom(kb * 1024))
    t = time.time() - age
    os.utime(path, (t, t))
for name in ("CACHEDIR.TAG", ".rustc_info.json"):
    put(name, 0, 0)
for prof in ("debug", "release"):
    for lock in (".cargo-lock", ".cargo-build-lock", ".cargo-artifact-lock"):
        put(f"{prof}/{lock}", 0, 0)
put("debug/app", 40, 50 * day)
put("debug/deps/libold-aaaaaaaaaaaaaaaa.rlib", 40, 30 * day)
put("debug/deps/old-aaaaaaaaaaaaaaaa.d", 1, 30 * day)
put("debug/.fingerprint/old-aaaaaaaaaaaaaaaa/lib-old", 1, 30 * day)
put("debug/incremental/old-2axyao3nv6b3e/s-1/query-cache.bin", 40, 20 * day)
put("debug/deps/libmid-bbbbbbbbbbbbbbbb.rlib", 40, 10 * day)
put("debug/deps/libnew-cccccccccccccccc.rlib", 40, 3600)
put("release/deps/librel-dddddddddddddddd.rlib", 40, 40 * day)
# A folder's own date counts too, as cargo leaves it: the day it was written.
for rel, age in (("debug/.fingerprint/old-aaaaaaaaaaaaaaaa", 30), ("debug/incremental/old-2axyao3nv6b3e/s-1", 20),
                 ("debug/incremental/old-2axyao3nv6b3e", 20)):
    t = time.time() - age * day
    os.utime(os.path.join(root, rel), (t, t))
PY
}
# Through the fake ps, which lists no compiler unless asked: this machine's own
# builds are not the suite's business.
# The disk is seen half free: under 15% free the cap is halved, and a machine
# whose disk is that full (a sandbox, measured 2026-10-13) halved every cap here
# and failed the checks that are about something else. The halving has a check
# of its own below.
trimpy() { rm -f "$tmp/trim-ps"; env PATH="$bo/bin:$PATH" PS_COUNT="$tmp/trim-ps" "$py" -c 'import collections, runpy, shutil, sys; D = collections.namedtuple("D", "total used free"); shutil.disk_usage = lambda p: D(100, 50, 50); sys.argv = sys.argv[1:]; runpy.run_path(sys.argv[0], run_name="__main__")' "$root/.ai-backbone/buildtrim.py" "$@"; }
kb() { "$py" -c "print(round($1 / 1048576, 9))"; }
tt="$tmp/tt"; mkcargo "$tt/target"
if "$py" -c 'import fcntl' 2>/dev/null; then
  # A build running in release: its lock held by another process.
  "$py" -c "import fcntl, os, sys, time; fd = os.open('$tt/target/release/.cargo-build-lock', os.O_RDWR); fcntl.flock(fd, fcntl.LOCK_EX); open('$tt/locked', 'w').close(); time.sleep(60)" & lk=$!
  i=0; until [ -e "$tt/locked" ] || [ "$i" -ge 50 ]; do sleep 0.1; i=$((i + 1)); done
  out=$(trimpy "$tt/target" "$(kb 100)" --now 2>&1)
  suite_stop "$lk"
  check "over its cap, a cargo folder loses its old pieces, whole units at a time" "[ ! -e '$tt/target/debug/deps/libold-aaaaaaaaaaaaaaaa.rlib' ] && [ ! -e '$tt/target/debug/deps/old-aaaaaaaaaaaaaaaa.d' ] && [ ! -d '$tt/target/debug/.fingerprint/old-aaaaaaaaaaaaaaaa' ] && [ ! -d '$tt/target/debug/incremental/old-2axyao3nv6b3e' ] && [ ! -e '$tt/target/debug/deps/libmid-bbbbbbbbbbbbbbbb.rlib' ]"
  check "and keeps a piece younger than 6 hours, the program itself, and a profile whose build is running" "[ -e '$tt/target/debug/deps/libnew-cccccccccccccccc.rlib' ] && [ -e '$tt/target/debug/app' ] && [ -e '$tt/target/release/deps/librel-dddddddddddddddd.rlib' ] && grep -q 'removed .* in 3 pieces' <<<\"\$out\" && grep -q 'release in use by a build or its programs, left alone' <<<\"\$out\""
  check "the run is one line in the folder's log" "[ \$(wc -l < '$tt/target/ai-backbone-trim.log') -eq 1 ] && grep -q 'over the cap' '$tt/target/ai-backbone-trim.log'"
  # Down to 75% of the cap, oldest first, and no further.
  t4="$tmp/t4/target"; mkdir -p "$t4/debug/deps"; : > "$t4/CACHEDIR.TAG"; : > "$t4/.rustc_info.json"
  for x in a:40 b:30 c:20 d:10; do n=${x%%:*}; age=${x#*:}
    "$py" -c "import os, time; p = '$t4/debug/deps/lib$n-$(printf "$n%.0s" 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16).rlib'; open(p, 'wb').write(os.urandom(200 * 1024)); t = time.time() - $age * 86400; os.utime(p, (t, t))"; done
  trimpy "$t4" "$(kb 760)" >/dev/null 2>&1
  check "it stops at 75% of the cap, the oldest gone first" "[ ! -e '$t4/debug/deps/liba-aaaaaaaaaaaaaaaa.rlib' ] && [ ! -e '$t4/debug/deps/libb-bbbbbbbbbbbbbbbb.rlib' ] && [ -e '$t4/debug/deps/libc-cccccccccccccccc.rlib' ] && [ -e '$t4/debug/deps/libd-dddddddddddddddd.rlib' ]"
  check "under its cap it removes nothing and says so" "says 'under the cap of .*: nothing removed' trimpy '$t4' 1 --now && [ -e '$t4/debug/deps/libc-cccccccccccccccc.rlib' ]"
  # Nothing in a profile a running program uses: cargo lets go of its locks
  # when compiling ends, and the tests it then runs need what is in deps/.
  t5="$tmp/t5/target"; mkcargo "$t5"
  out=$(PS_BUSY=99 PS_USES="/home/someone/.rustup/toolchains/stable/bin/rustc --crate-name t --out-dir $(winpath "$t5")/debug/deps" trimpy "$t5" "$(kb 100)" --now 2>&1)
  check "a profile a running program uses is left alone, said, and the run is not counted as done" "grep -q 'debug in use by a build or its programs, left alone' <<<\"\$out\" && [ -e '$t5/debug/deps/libold-aaaaaaaaaaaaaaaa.rlib' ] && [ ! -e '$t5/ai-backbone-trim.done' ]"
  out=$(PS_LATER=1 PS_USES="$(winpath "$t5")/debug/deps/t-aaaaaaaaaaaaaaaa --test-threads 1" trimpy "$t5" "$(kb 100)" --now 2>&1)
  check "and one a test program starts to use after the first look" "grep -q 'debug in use by a build or its programs, left alone' <<<\"\$out\" && [ -e '$t5/debug/deps/libold-aaaaaaaaaaaaaaaa.rlib' ] && [ ! -e '$t5/ai-backbone-trim.done' ]"
  # A build of another folder, and a server run from the top of a profile,
  # hold nothing back (3.38.1: with six projects building there was always one).
  t6="$tmp/t6/target"; mkcargo "$t6"
  out=$(PS_BUSY=99 PS_USES="$(winpath "$t6")/debug/app serve --port 8080" trimpy "$t6" "$(kb 100)" --now 2>&1)
  check "a build elsewhere and a program run from the top of a profile hold nothing back" "[ ! -e '$t6/debug/deps/libold-aaaaaaaaaaaaaaaa.rlib' ] && [ -e '$t6/debug/app' ] && ! grep -q 'in use by' <<<\"\$out\""
  t7="$tmp/t7/target"; mkcargo "$t7"
  out=$(PS_FAIL=1 trimpy "$t7" "$(kb 100)" --now 2>&1)
  check "a process list that cannot be read removes nothing" "grep -q 'the process list cannot be read.*nothing removed' <<<\"\$out\" && [ -e '$t7/debug/deps/libold-aaaaaaaaaaaaaaaa.rlib' ]"
  "$py" -c "import fcntl, os, time; fd = os.open('$t5/ai-backbone-trim.lock', os.O_RDWR | os.O_CREAT); fcntl.flock(fd, fcntl.LOCK_EX); open('$t5/held', 'w').close(); time.sleep(60)" & tl=$!
  i=0; until [ -e "$t5/held" ] || [ "$i" -ge 50 ]; do sleep 0.1; i=$((i + 1)); done
  check "one run at a time" "says 'Another trim of this folder is running' trimpy '$t5' '$(kb 100)' --now && [ -e '$t5/debug/deps/libold-aaaaaaaaaaaaaaaa.rlib' ]"
  suite_stop "$tl"
  check "with less than 15% of the disk free the cap is halved" "\"\$py\" -c 'import importlib.util as i, collections, sys; s = i.spec_from_file_location(\"b\", \"$rootw/.ai-backbone/buildtrim.py\"); b = i.module_from_spec(s); s.loader.exec_module(b); D = collections.namedtuple(\"D\", \"total used free\"); b.shutil.disk_usage = lambda p: D(100, 90, 10); line = b.trim(b.Path(\"$t4\"), 1024 ** 3)[0]; sys.exit(0 if \"halved: 10% of the disk is free\" in line else 1)'"
else
  out=$(trimpy "$tt/target" "$(kb 100)" --now 2>&1)
  check "where cargo's locks cannot be read (no fcntl), nothing is removed" "[ -e '$tt/target/debug/deps/libold-aaaaaaaaaaaaaaaa.rlib' ] && grep -q 'cannot be read on this system' <<<\"\$out\""
fi
check "the cap reads GB as written, 0 or off as off, and nothing else" "\"\$py\" -c 'import importlib.util as i, sys; s = i.spec_from_file_location(\"b\", \"$rootw/.ai-backbone/buildtrim.py\"); b = i.module_from_spec(s); s.loader.exec_module(b); sys.exit(0 if [b.parse_cap(x) for x in (\"60\", \"30GB\", \"30 gb\", \"1.5\", \"0\", \"0 GB\", \"00\", \"off\", \"x\", \"-1\")] == [60, 30, 30, 1.5, 0, 0, 0, 0, None, None] else 1)'"
check "a cap that says neither is said, and 60 is used" "says 'build-cap .x. is not a number of GB, so 60 is used; .*under the cap of 60.0 GB' trimpy '$tt/target' x --now"
mkdir -p "$tmp/notcargo/debug/deps"; printf 'x' > "$tmp/notcargo/debug/deps/libx-aaaaaaaaaaaaaaaa.rlib"
check "a folder without cargo's marks is never touched" "says 'is not a folder cargo made' trimpy '$tmp/notcargo' '$(kb 1)' --now && [ -e '$tmp/notcargo/debug/deps/libx-aaaaaaaaaaaaaaaa.rlib' ]"
# The recipes, in the Rust layer's project: the folder comes from the layer.
cd "$bo/proj" || exit 1
mkcargo "$tmp/tr/target"
# The suite turns trimming off for itself; these turn it on, outside CI.
tcap() { local c=$1; shift; bw env -u CI GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=ai-backbone.build-cap GIT_CONFIG_VALUE_0="$c" CARGO_META_TARGET="$tmp/tr/target" "$@"; }
check "just trim-build runs now and says what it did" "says '^[0-9-]+ [0-9:]+  .*under the cap of (60|30).0 GB' tcap 60 just trim-build"
check "and off turns it off" "says 'Trimming is off here' tcap off just trim-build"
check "a folder that is not cargo's is left alone by the recipe too" "says 'is not a folder cargo made' tcap 60 env -u CARGO_META_TARGET just trim-build"
# A Rust workspace below the root: the recipe finds every folder cargo made,
# not only the one the layer names (n-2a36ec).
mkcargo "$bo/proj/src/app/target"
# Where cargo's locks can be read, the nested folder is trimmed. Where they
# cannot (no fcntl, spec 020), it is still found and nothing is removed.
if "$py" -c 'import fcntl' 2>/dev/null; then
  check "trim-build finds a nested workspace's build folder too" "says 'over the cap of .*: removed' tcap 0.0001 env -u CARGO_META_TARGET just trim-build && [ ! -e '$bo/proj/src/app/target/debug/deps/libold-aaaaaaaaaaaaaaaa.rlib' ] && grep -q 'over the cap' '$bo/proj/src/app/target/ai-backbone-trim.log'"
else
  check "trim-build finds a nested workspace's build folder too" "says 'over the cap of .*; cargo.s locks cannot be read' tcap 0.0001 env -u CARGO_META_TARGET just trim-build && [ -e '$bo/proj/src/app/target/debug/deps/libold-aaaaaaaaaaaaaaaa.rlib' ] && grep -q 'cargo.s locks cannot be read' '$bo/proj/src/app/target/ai-backbone-trim.log'"
fi
rm -f "$tmp/tr/target/ai-backbone-trim.log" "$tmp/tr/target/ai-backbone-trim.done"
tcap 60 env BUILD_WAIT_MINUTES=1 just _build-wait >/dev/null 2>&1
i=0; until [ -s "$tmp/tr/target/ai-backbone-trim.log" ] || [ "$i" -ge 100 ]; do sleep 0.1; i=$((i + 1)); done
check "every build that waits starts a trim in the background" "grep -q 'under the cap' '$tmp/tr/target/ai-backbone-trim.log'"
tcap 60 env BUILD_WAIT_MINUTES=1 just _build-wait >/dev/null 2>&1; sleep 2
check "at most once an hour" "[ \$(wc -l < '$tmp/tr/target/ai-backbone-trim.log') -eq 1 ]"
rm -f "$tmp/tr/target/ai-backbone-trim.log" "$tmp/tr/target/ai-backbone-trim.done"
tcap 60 env CI=true BUILD_WAIT_MINUTES=1 just _build-wait >/dev/null 2>&1; sleep 2
check "and never on CI" "[ ! -e '$tmp/tr/target/ai-backbone-trim.log' ]"
# A disk nearly full is said at the start of every session.
mkdir -p "$tmp/fakedf"; printf '#!/bin/sh\necho "Filesystem 1024-blocks Used Available Capacity Mounted on"\necho "/dev/x 100000000 95000000 5000000 95%% /"\n' > "$tmp/fakedf/df"; chmod +x "$tmp/fakedf/df"
mkdir -p "$tmp/fakedf2"; sed 's/95000000 5000000 95%/50000000 50000000 50%/' "$tmp/fakedf/df" > "$tmp/fakedf2/df"; chmod +x "$tmp/fakedf2/df"
check "session-start says when the disk is nearly full" "says '^Disk: only 5% free here \(4 GB\)\. Build output is the usual cause -> just trim-build' env PATH='$tmp/fakedf:$PATH' just session-start"
check "and nothing when it is not" "! says '^Disk:' env PATH='$tmp/fakedf2:$PATH' just session-start"
# One disk, many projects (spec 032). Two Rust projects beside this one, each
# capped at 30 GB like it: 90 GB of caps on a 95 GB disk is said, on a 953 GB
# one it is not. A sibling's layer here only names its folder.
rp="$tmp/rp"
for n in p1 p2; do
  mkdir -p "$rp/$n/.ai-backbone"; : > "$rp/$n/.ai-backbone/core.just"; git -C "$rp/$n" init -q
  printf '# a layer for cargo\n_build-info:\n    @echo "dir %s"\n' "$tmp/rp-target-$n" > "$rp/$n/stack.just"
  printf 'import "stack.just"\n' > "$rp/$n/Justfile"
done
mkdir -p "$tmp/fakedf3"; sed 's/100000000 50000000 50000000/1000000000 500000000 500000000/' "$tmp/fakedf2/df" > "$tmp/fakedf3/df"; chmod +x "$tmp/fakedf3/df"
# Fake df first, then the suite's cargo: without it, doctor runs real
# `cargo metadata` and on Windows that waits on the registry lock the
# job's cargo-audit install left (the rest lane's 40-minute cut).
out=$(tcap 30 env AI_BACKBONE_PROJECTS="$rp" PATH="$tmp/fakedf2:$bo/bin:$PATH" just doctor 2>&1)
check "doctor says when the build caps of the machine's Rust projects pass half the disk, with a cap that fits" "grep -q 'build caps of this machine.s 3 Rust projects add up to 90 GB, more than half the 95 GB disk' <<<\"\$out\" && grep -q 'A cap that fits: git config --global ai-backbone.build-cap 15' <<<\"\$out\""
out=$(tcap 30 env AI_BACKBONE_PROJECTS="$rp" PATH="$tmp/fakedf3:$bo/bin:$PATH" just doctor 2>&1)
check "and nothing when they fit" "! grep -q 'build caps of this machine' <<<\"\$out\""
out=$(tcap off env AI_BACKBONE_PROJECTS="$rp" PATH="$tmp/fakedf2:$bo/bin:$PATH" just doctor 2>&1)
check "a cap that is off adds nothing" "! grep -q 'build caps of this machine' <<<\"\$out\""
# Under 15% free, a build's trim goes into the idle sibling's folder too, where cargo's locks can be read.
if "$py" -c 'import fcntl' 2>/dev/null; then
  mkcargo "$tmp/rp-target-p1"; rm -f "$tmp/tr/target/ai-backbone-trim.done"
  # The fake ps, not this machine's: a seatbelt refuses `ps -A`, and a trim that
  # cannot read the process list removes nothing and writes no log.
  tcap 60 env AI_BACKBONE_PROJECTS="$rp" PATH="$tmp/fakedf:$bo/bin:$PATH" just _build-trim auto >/dev/null 2>&1
  check "with the disk under 15% free, a build's trim also trims a project idle for a week" "grep -q 'last built 30 days ago: removed' '$tmp/rp-target-p1/ai-backbone-trim.log'"
fi
cd "$tmp" || exit 1
# The order and the limits, against a disk seen 10% free: an idle folder loses
# its working set too, oldest used first; a folder built today, or one a program
# uses, keeps everything; a piece younger than 6 hours stays.
if "$py" -c 'import fcntl' 2>/dev/null; then
  mfull() { env PATH="$bo/bin:$PATH" "$py" -c 'import collections, runpy, shutil, sys; D = collections.namedtuple("D", "total used free"); shutil.disk_usage = lambda p: D(10 * 1048576, 9 * 1048576, 1048576); sys.argv = sys.argv[1:]; runpy.run_path(sys.argv[0], run_name="__main__")' "$root/.ai-backbone/buildtrim.py" --machine "$@"; }
  mo="$tmp/m/own"; mkcargo "$mo"; mi="$tmp/m/idle"; mkcargo "$mi"; mn="$tmp/m/new"; mkcargo "$mn"; mu="$tmp/m/used"; mkcargo "$mu"
  touch "$mn/debug/.fingerprint/old-aaaaaaaaaaaaaaaa"
  out=$(PS_BUSY=99 PS_USES="rustc --out-dir $(winpath "$mu")/debug/deps" mfull "$mo" "$mi" "$mn" "$mu" 2>&1)
  check "an idle folder loses what a build makes again, its working set too" "[ ! -e '$mi/debug/deps/libold-aaaaaaaaaaaaaaaa.rlib' ] && [ ! -e '$mi/debug/deps/libmid-bbbbbbbbbbbbbbbb.rlib' ] && [ ! -e '$mi/release/deps/librel-dddddddddddddddd.rlib' ] && grep -q 'last built 30 days ago: removed' '$mi/ai-backbone-trim.log'"
  check "and keeps a piece younger than 6 hours and the program itself" "[ -e '$mi/debug/deps/libnew-cccccccccccccccc.rlib' ] && [ -e '$mi/debug/app' ]"
  check "a folder built today, its own folder, and one a program uses keep everything" "[ -e '$mn/debug/deps/libold-aaaaaaaaaaaaaaaa.rlib' ] && [ -e '$mo/debug/deps/libold-aaaaaaaaaaaaaaaa.rlib' ] && [ -e '$mu/debug/deps/libold-aaaaaaaaaaaaaaaa.rlib' ] && grep -q 'in use now: left alone' '$mu/ai-backbone-trim.log'"
  mi2="$tmp/m2/idle"; mkcargo "$mi2"
  out=$(env PATH="$bo/bin:$PATH" "$py" -c 'import collections, runpy, shutil, sys; D = collections.namedtuple("D", "total used free"); shutil.disk_usage = lambda p: D(100, 50, 50); sys.argv = sys.argv[1:]; runpy.run_path(sys.argv[0], run_name="__main__")' "$root/.ai-backbone/buildtrim.py" --machine "$mo" "$mi2" 2>&1)
  check "with the disk 15% free or more, no other folder is touched" "[ -z \"\$out\" ] && [ -e '$mi2/debug/deps/libold-aaaaaaaaaaaaaaaa.rlib' ] && [ ! -e '$mi2/ai-backbone-trim.log' ]"
  # A little short of 20%: the folder built longest ago gives it, and the
  # next one is not reached.
  ma="$tmp/m3/older"; mkcargo "$ma"; mb="$tmp/m3/newer"; mkcargo "$mb"
  "$py" -c "import os, time; t = time.time() - 40 * 86400; os.utime('$ma/debug/.fingerprint/old-aaaaaaaaaaaaaaaa', (t, t))"
  env PATH="$bo/bin:$PATH" "$py" -c 'import collections, runpy, shutil, sys; D = collections.namedtuple("D", "total used free"); shutil.disk_usage = lambda p: D(1700 * 1024, 1462 * 1024, 238 * 1024); sys.argv = sys.argv[1:]; runpy.run_path(sys.argv[0], run_name="__main__")' "$root/.ai-backbone/buildtrim.py" --machine "$mo" "$mb" "$ma" >/dev/null 2>&1
  check "the one built longest ago goes first, and the trim stops at 20% free" "[ ! -e '$ma/release/deps/librel-dddddddddddddddd.rlib' ] && grep -q 'last built 40 days ago: removed' '$ma/ai-backbone-trim.log' && [ -e '$mb/debug/deps/libold-aaaaaaaaaaaaaaaa.rlib' ] && [ ! -e '$mb/ai-backbone-trim.log' ]"
fi
cd "$tmp" || exit 1

fi
if lane_wants b28; then
section "the backlog of 2026-10-13 (spec 028)"
# A folder the person made and opened first is taken while it is empty.
mkdir -p "$tmp/s28" "$tmp/s28-full"; : > "$tmp/s28-full/x.txt"
check "new-project takes a folder that is there and empty" "( cd '$root' && just new-project '$tmp/s28' ) >/dev/null 2>&1 && [ -f '$tmp/s28/AGENTS.md' ] && [ -n \"\$(git -C '$tmp/s28' log --oneline 2>/dev/null)\" ]"
mkdir -p "$tmp/My Own"
check "and the folder the person made is the one meant, whatever its name" "( cd '$root' && just new-project '$tmp/My Own' ) >/dev/null 2>&1 && [ -f '$tmp/My Own/AGENTS.md' ] && [ ! -e '$tmp/my-own' ]"
check "and refuses one with something in it" "! ( cd '$root' && just new-project '$tmp/s28-full' ) >/dev/null 2>&1 && says 'is not empty' bash -c \"cd '$root' && just new-project '$tmp/s28-full'\" && [ ! -e '$tmp/s28-full/AGENTS.md' ]"
cd "$tmp/s28" || exit 1
# ref-add: a git bundle, and a folder read where it stands.
mkdir -p "$tmp/s28-old" "$tmp/s28-sib"; git -C "$tmp/s28-old" init -q; : > "$tmp/s28-old/f"; git -C "$tmp/s28-old" add f; git -C "$tmp/s28-old" commit -qm x --no-verify
git -C "$tmp/s28-old" bundle create "$tmp/Old.bundle" --all >/dev/null 2>&1
check "ref-add clones a git bundle and lists it local only" "just ref-add '$tmp/Old.bundle' 'an old copy' >/dev/null 2>&1 && [ -f .references/old/f ] && grep -q '^from   = .*Old.bundle\"\$' .references/references.toml"
git -C "$tmp/s28-old" bundle create "$tmp/One.bundle" "$(git -C "$tmp/s28-old" symbolic-ref --short HEAD)" >/dev/null 2>&1
check "a bundle of one branch, which carries no HEAD, comes out with its files" "just ref-add '$tmp/One.bundle' 'one branch' >/dev/null 2>&1 && [ -f .references/one/f ]"
check "ref-add <folder> live lists it where it stands and clones nothing" "just ref-add '$tmp/s28-sib' 'a sibling' live >/dev/null 2>&1 && [ ! -e .references/s28-sib ] && grep -q '^status = \"live\"' .references/references.toml && says 's28-sib .local only, read where it stands' just ref-fetch"
check "and a third word other than live is refused" "! just ref-add '$tmp/s28-sib' x lively 2>/dev/null"
mkdir -p "$tmp/s28-b/s28-sib"
check "a second live folder of the same name is refused, the first kept" "! just ref-add '$tmp/s28-b/s28-sib' y live >/dev/null 2>&1 && [ \$(grep -c '^name   = \"s28-sib\"' .references/references.toml) -eq 1 ] && says 'listed  already' just ref-add '$tmp/s28-sib' again live"
# The Rust layer: its ignore lines, a first save before cargo init, the version.
printf 'target/\n' >> .gitignore
check "stack rust adds the layer's ignore lines, each once" "just stack rust >/dev/null 2>&1 && [ \$(grep -cx 'target/' .gitignore) -eq 1 ] && grep -qxF '*.rs.bk' .gitignore"
lint28=$(just lint 2>&1); rc28=$?
check "with no Cargo.toml yet, lint and test say so and pass, so the first save goes through" "[ $rc28 -eq 0 ] && grep -q 'No Cargo.toml yet' <<<\"\$lint28\" && ! grep -q 'error:' <<<\"\$lint28\" && just test >/dev/null 2>&1 && just save 'chore: the rust layer' >/dev/null 2>&1"
perl -0pi -e 's/\n_set-version version:/\n_set_version_gone version:/' stack.just
printf '[package]\nname = "s28"\nversion = "0.1.0"\n' > Cargo.toml
# One doctor before and one after, each read for two things: the suite has a
# time limit on every machine, and a doctor costs seconds on a runner.
doc28=$(just doctor 2>&1)
check "doctor says when the layer cannot move the version in Cargo.toml" "grep -q 'release does not move the version in Cargo.toml' <<<\"\$doc28\""
# Claude Code's SessionStart hook: the tools' folders for the agent's Bash, and
# a mark that the hook ran, which doctor reads.
check "doctor says when the session-start hook has not run here" "grep -q 'session-start hook has not run on this machine' <<<\"\$doc28\""
cp "$root/.ai-backbone/examples/stack-rust.just" stack.just
: > "$tmp/s28-env"; mkdir -p "$tmp/s28h/.local/bin"; printf '#!/bin/sh\necho prek 0.0.1\n' > "$tmp/s28h/.local/bin/prek"; chmod +x "$tmp/s28h/.local/bin/prek"
hook28() { env CLAUDE_ENV_FILE="$tmp/s28-env" HOME="$tmp/s28h" PATH="$tmp/s28h/.local/bin:$PATH" just session-start >/dev/null 2>&1; }
check "as the hook, session-start writes ~/.local/bin to CLAUDE_ENV_FILE, at the end of PATH, once" "hook28; hook28; [ \$(grep -c . '$tmp/s28-env') -eq 1 ] && grep -qx \"export PATH=\\\"\\\$PATH:$tmp/s28h/.local/bin\\\"\" '$tmp/s28-env'"
doc28=$(just doctor 2>&1); rm -f Cargo.toml
check "and doctor then says it ran" "grep -q 'session-start hook ran here, last on' <<<\"\$doc28\""
check "and nothing about the version once the layer has _set-version" "! grep -q 'does not move the version' <<<\"\$doc28\""
cd "$tmp" || exit 1

fi
if lane_wants b29; then
section "the backlog of 2026-10-14 (spec 029)"
# RustSec: an advisory database in the archive's own layout, and a Cargo.lock.
adb="$tmp/s29-adb/advisory-db-main/crates"; mkdir -p "$adb/foo" "$adb/bar" "$adb/old"
adv29() { printf '```toml\n[advisory]\nid = "%s"\npackage = "%s"\ndate = "2099-01-01"\n%s\n[versions]\npatched = [%s]\nunaffected = [%s]\n```\n\n# %s\n\nText.\n' "$@"; }
adv29 RUSTSEC-2099-0001 foo "" '">= 1.2.3"' '"< 1.0.0"' 'Foo overflows' > "$adb/foo/RUSTSEC-2099-0001.md"
adv29 RUSTSEC-2099-0002 foo 'withdrawn = "2099-02-01"' '' '' 'Foo was wrong' > "$adb/foo/RUSTSEC-2099-0002.md"
adv29 RUSTSEC-2099-0003 bar 'informational = "unmaintained"' '' '' 'Bar is unmaintained' > "$adb/bar/RUSTSEC-2099-0003.md"
adv29 RUSTSEC-2099-0004 old "" '"^0.2.5", ">= 0.3.1"' '' 'Old is old' > "$adb/old/RUSTSEC-2099-0004.md"
cp -R "$tmp/s29-adb/advisory-db-main" "$tmp/s29-db"; printf '2099-01-01\n' > "$tmp/s29-db/ai-backbone.fetched"
# The archive, with a path that climbs out and a file outside crates/.
mkdir -p "$tmp/s29-adb/advisory-db-main/crates/foo/x" && : > "$tmp/s29-adb/advisory-db-main/README.md"
"$py" - "$(winpath "$tmp/s29-adb")" "$(winpath "$tmp/s29.tgz")" <<'PY'
import io, sys, tarfile
src, out = sys.argv[1], sys.argv[2]
with tarfile.open(out, "w:gz") as t:
    t.add(f"{src}/advisory-db-main", arcname="advisory-db-main")
    evil = tarfile.TarInfo("advisory-db-main/crates/../evil.md"); data = b"x"; evil.size = 1
    t.addfile(evil, io.BytesIO(data))
PY
lock29() { printf 'version = 4\n'; while [ $# -gt 0 ]; do printf '\n[[package]]\nname = "%s"\nversion = "%s"\nsource = "%s"\n' "$1" "$2" "$3"; shift 3; done; }
reg="registry+https://github.com/rust-lang/crates.io-index"
if ( cd "$root" && just new-project "$tmp/s29" ) >/dev/null 2>&1; then ok "a project for spec 029"; else bad "a project for spec 029"; fi
cd "$tmp/s29" || exit 1
lock29 foo 1.2.0 "$reg" bar 0.1.0 "sparse+https://index.crates.io/" old 0.2.7 "$reg" foo 1.1.0 "git+https://example.com/foo" > Cargo.lock
dbenv() { env AI_BACKBONE_ADVISORY_DB="$(winpath "$tmp/s29-db")" "$@"; }
if "$py" -c 'import tomllib' 2>/dev/null; then
  doc29=$(dbenv just doctor 2>&1)
  check "doctor names the crate, its version, the advisory, its title and the fixed version" "grep -q '^  warn  Cargo.lock: foo 1.2.0 has RUSTSEC-2099-0001, Foo overflows -> fixed in >= 1.2.3' <<<\"\$doc29\""
  check "and leaves out a withdrawn advisory, a fixed version and a crate from git" "! grep -qE 'RUSTSEC-2099-0002|RUSTSEC-2099-0004|foo 1.1.0' <<<\"\$doc29\""
  check "and counts a notice apart, as no vulnerability" "grep -q '^  info  Cargo.lock: notices, not vulnerabilities (unmaintained: bar)' <<<\"\$doc29\" && grep -q 'RustSec database of 2099-01-01' <<<\"\$doc29\""
  check "session-start says the finding" "o=\$(dbenv just session-start 2>&1); grep -q '^=== RUST ADVISORIES (1; RustSec database of 2099-01-01) ===' <<<\"\$o\" && grep -q '^- Cargo.lock: foo 1.2.0 has RUSTSEC-2099-0001' <<<\"\$o\""
  lock29 foo 1.2.3 "$reg" old 0.3.1 "$reg" > Cargo.lock
  check "a fixed version: doctor says so, session-start says nothing" "says '^  ok    Cargo.lock: no RustSec advisory for its 2 crates' dbenv just doctor && ! says 'RUST ADVISORIES' dbenv just session-start"
  # Fetched: once a day at most, only crates/**/*.md, nothing outside the cache.
  # Asked directly here, not through doctor: a doctor costs seconds on a runner.
  xdg="$tmp/s29-xdg"; fenv() { env -u AI_BACKBONE_OFFLINE XDG_CACHE_HOME="$(winpath "$xdg")" AI_BACKBONE_ADVISORY_URL="$(fileurl "$tmp/s29.tgz")" "$py" "$root/.ai-backbone/upstream.py" --advisories doctor Cargo.lock; }
  check "the database is fetched into the cache, and only its advisories" "( cd '$tmp/s29' && says 'no RustSec advisory for its 2 crates' fenv ) && [ -f '$xdg/ai-backbone/advisory-db/crates/foo/RUSTSEC-2099-0001.md' ] && [ ! -e '$xdg/ai-backbone/advisory-db/README.md' ] && [ ! -e '$xdg/ai-backbone/advisory-db/evil.md' ] && [ ! -e '$xdg/ai-backbone/evil.md' ]"
  mv "$tmp/s29.tgz" "$tmp/s29-gone.tgz"
  check "and read from the cache within a day, with no fetch" "o=\$(fenv 2>&1); grep -q 'no RustSec advisory for its 2 crates' <<<\"\$o\" && ! grep -q 'could not fetch' <<<\"\$o\""
  check "with nothing fetched and no network, the check says it did not run" "says 'Cargo.lock not read against RustSec: offline .*no copy of the advisory database here' env AI_BACKBONE_OFFLINE=1 XDG_CACHE_HOME='$(winpath "$tmp/s29-none")' '$py' '$root/.ai-backbone/upstream.py' --advisories doctor Cargo.lock"
  check "cargo's requirements are read as cargo reads them" "\"\$py\" -c 'import importlib.util as i, sys; s = i.spec_from_file_location(\"u\", \"$rootw/.ai-backbone/upstream.py\"); u = i.module_from_spec(s); s.loader.exec_module(u); c = [(\">= 0.3.47\", \"0.3.46\", 0), (\"^0.2.23\", \"0.2.30\", 1), (\"^0.2.23\", \"0.3.0\", 0), (\"^0.0.3\", \"0.0.4\", 0), (\"~1.2.3\", \"1.3.0\", 0), (\"1.2.*\", \"1.2.9\", 1), (\"1.2.*\", \"1.3.0\", 0), (\">1.2\", \"1.2.9\", 0), (\"<=1.2\", \"1.2.9\", 1), (\">= 1.0.0, < 1.5.2\", \"1.5.2\", 0), (\">= 0.5.0\", \"0.5.0-alpha.1\", 0), (\">= 0.5.0-alpha.2\", \"0.5.0-alpha.3\", 1), (\">= 0.8.1\", \"0.9.0-alpha.1\", 1), (\"1.2.3\", \"1.4.0\", 1)]; sys.exit(0 if all(bool(u.semver_matches(r, u.semver(v))) == bool(w) for r, v, w in c) else 1)'"
  # A crate watched from GitHub.
  mkdir -p docs; printf '[[watch]]\nname = "foo"\nsource = "github:someone/foo-rs"\npin = "1.2.3"\n\n[[watch]]\nname = "Old"\nsource = "crates:old"\npin = "0.3.1"\n\n[[watch]]\nname = "tool"\nsource = "github:someone/tool"\npin = "v1"\n' > docs/upstream.toml
  doc29=$(dbenv just doctor 2>&1)
  check "a github: row for a crate Cargo.lock locks is named, with the crates: source to write" "[ \$(grep -c 'reads .* from github:' <<<\"\$doc29\") -eq 1 ] && grep -q 'reads foo from github:someone/foo-rs, and Cargo.lock locks the crate foo: .*source = \"crates:foo\"' <<<\"\$doc29\""
else
  check "without tomllib, doctor says what the advisory check needs" "says 'Cargo.lock not read against RustSec: needs Python 3.11' just doctor"
fi
cd "$tmp" || exit 1
# The trim's order: what only an old root reaches goes first; what the newest
# root reaches stays, however long ago it was written.
if "$py" -c 'import fcntl' 2>/dev/null; then
  mkgraph() {
    "$py" - "$@" <<'PY'
import json, os, sys, time
root, day = sys.argv[1], 86400
# Ages in hours of the old root, the piece only it reaches, and the new root.
old, gone, new = (float(x) * 3600 for x in (sys.argv[2:5] if len(sys.argv) > 4 else (240, 480, 48)))
def put(rel, size, age):
    p = os.path.join(root, rel); os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, "wb") as f: f.write(os.urandom(size))
    t = time.time() - age; os.utime(p, (t, t))
def unit(name, h, kind, fp, deps, age, size):
    put(f"debug/deps/lib{name}-{h}.rlib", size, age)
    fd = f"debug/.fingerprint/{name}-{h}"
    os.makedirs(os.path.join(root, fd), exist_ok=True)
    with open(os.path.join(root, fd, f"{kind}-{name}"), "w") as f: f.write(fp)
    with open(os.path.join(root, fd, f"{kind}-{name}.json"), "w") as f:
        json.dump({"rustc": 1, "deps": [[1, d, False, int.from_bytes(bytes.fromhex(v), "little")] for d, v in deps]}, f)
    for dirpath, _, files in os.walk(os.path.join(root, fd)):
        for x in files: t = time.time() - age; os.utime(os.path.join(dirpath, x), (t, t))
    t = time.time() - age; os.utime(os.path.join(root, fd), (t, t))
for n in ("CACHEDIR.TAG", ".rustc_info.json", "debug/.cargo-lock"): put(n, 0, 0)
unit("dep", "2222222222222222", "lib", "00000000000000d1", [], 40 * day, 200 * 1024)
unit("gone", "4444444444444444", "lib", "00000000000000a1", [], gone, 200 * 1024)
unit("app", "3333333333333333", "bin", "00000000000000b1", [("gone", "00000000000000a1")], old, 200 * 1024)
unit("app", "1111111111111111", "bin", "00000000000000c1", [("dep", "00000000000000d1"), ("twin", "00000000000000e1")], new, 200 * 1024)
# A build script run is fingerprinted without its profile: two runs, one value.
unit("twin", "5555555555555555", "run-build-script-build-script-build", "00000000000000e1", [], 40 * day, 100 * 1024)
unit("twin", "6666666666666666", "run-build-script-build-script-build", "00000000000000e1", [], 40 * day, 100 * 1024)
PY
  }
  g1="$tmp/g1/target"; mkgraph "$g1"
  trimpy "$g1" "$(kb 760)" >/dev/null 2>&1
  check "over the cap, what only an old root reaches goes before an older piece the newest root reaches" "[ -e '$g1/debug/deps/libdep-2222222222222222.rlib' ] && [ -e '$g1/debug/deps/libapp-1111111111111111.rlib' ] && [ ! -e '$g1/debug/deps/libgone-4444444444444444.rlib' ] && [ ! -e '$g1/debug/deps/libapp-3333333333333333.rlib' ]"
  check "and two pieces with one fingerprint, as two build script runs have, are both reached and stay" "[ -e '$g1/debug/deps/libtwin-5555555555555555.rlib' ] && [ -e '$g1/debug/deps/libtwin-6666666666666666.rlib' ]"
  g2="$tmp/g2/target"; mkgraph "$g2"
  out=$(trimpy "$g2" "$(kb 300)" --now 2>&1)
  check "and what the newest builds of the last day reach stays even under a cap too low for it, which is said" "[ -e '$g2/debug/deps/libdep-2222222222222222.rlib' ] && [ -e '$g2/debug/deps/libapp-1111111111111111.rlib' ] && grep -q 'more than 75% of the cap, so the cap is below what this project.s builds need' <<<\"\$out\""
  # The same program built again under a new hash the same day, by a feature
  # change or an update: what only the old one reached goes, past 6 hours.
  g3="$tmp/g3/target"; mkgraph "$g3" 8 9 7
  trimpy "$g3" "$(kb 760)" >/dev/null 2>&1
  check "a root a newer one of the same program replaced the same day leaves what only it reached" "[ -e '$g3/debug/deps/libdep-2222222222222222.rlib' ] && [ ! -e '$g3/debug/deps/libgone-4444444444444444.rlib' ] && [ ! -e '$g3/debug/deps/libapp-3333333333333333.rlib' ]"
fi
check "the night section says what a series does next, and what an unmet dependency does" "grep -q 'approved several night specs at once as a series' '$root/.agents/skills/spec/SKILL.md' && grep -q 'is skipped, never half' '$root/.agents/skills/spec/SKILL.md'"

fi
if lane_wants advisory; then
section "an advisory looked at, written down (spec 030)"
# The project of spec 029, its database, and two more advisories: a second one
# for foo, and one for baz with no fix.
if "$py" -c 'import tomllib' 2>/dev/null && cd "$tmp/s29"; then
  db30="$tmp/s30-db"; cp -R "$tmp/s29-db" "$db30"; mkdir -p "$db30/crates/baz"
  adv29 RUSTSEC-2099-0005 foo "" '">= 1.2.2"' '' 'Foo leaks' > "$db30/crates/foo/RUSTSEC-2099-0005.md"
  adv29 RUSTSEC-2099-0006 baz "" '' '' 'Baz is broken' > "$db30/crates/baz/RUSTSEC-2099-0006.md"
  lock29 foo 1.2.0 "$reg" baz 0.1.0 "$reg" > Cargo.lock
  lock29 foo 1.2.3 "$reg" > "$tmp/s30-clean.lock"
  day30() { "$py" -c 'import datetime, sys; print(datetime.date.today() + datetime.timedelta(days=int(sys.argv[1])))' "$1"; }
  row30() { printf '[[triaged]]\nid = "%s"\ncrate = "%s"\nwhy = "%s"\nfixed = "%s"\nuntil = %s\n\n' "$@"; }
  env30() { env AI_BACKBONE_ADVISORY_DB="$(winpath "$db30")" "$@"; }
  u30() { env30 "$py" "$root/.ai-backbone/upstream.py" --advisories "$@"; }
  gate30() { out30=$(u30 gate "$@" 2>&1); rc30=$?; }
  { row30 RUSTSEC-2099-0001 foo "only tests build it" ">= 1.2.3" "$(day30 30)"
    row30 RUSTSEC-2099-0006 baz "the input is our own" none "$(day30 90)"
    row30 RUSTSEC-2099-0009 gone x none "$(day30 5)"; } > docs/advisories.toml
  o30=$(env30 just session-start 2>&1)
  check "session-start is quiet about a triaged advisory, says a second one of the same crate, and where a row goes" "grep -q '^=== RUST ADVISORIES (1; ' <<<\"\$o30\" && grep -q '^- Cargo.lock: foo 1.2.0 has RUSTSEC-2099-0005, Foo leaks -> fixed in >= 1.2.2 (' <<<\"\$o30\" && ! grep -qE 'RUSTSEC-2099-000[16]' <<<\"\$o30\" && grep -q 'gets a row in docs/advisories.toml' <<<\"\$o30\""
  d30=$(env30 just doctor 2>&1)
  check "doctor lists a triaged advisory with its day and reason, and a row nothing needs" "grep -q \"^  info  Cargo.lock: foo 1.2.0 has RUSTSEC-2099-0001, triaged until $(day30 30): only tests build it\" <<<\"\$d30\" && grep -q '^  warn  Cargo.lock: foo 1.2.0 has RUSTSEC-2099-0005' <<<\"\$d30\" && grep -q '^  info  docs/advisories.toml: RUSTSEC-2099-0009 (gone) is in no Cargo.lock any more -> remove the row' <<<\"\$d30\""
  gate30 --triaged docs/advisories.toml Cargo.lock
  check "the gate says each advisory on a line of its own, no reason, and refuses the one with no row" "[ $rc30 -eq 1 ] && grep -q '^triaged Cargo.lock: foo 1.2.0 RUSTSEC-2099-0001 -> fixed in >= 1.2.3 (triaged until ' <<<\"\$out30\" && grep -q '^untriaged Cargo.lock: foo 1.2.0 RUSTSEC-2099-0005 -> fixed in >= 1.2.2$' <<<\"\$out30\" && grep -q '^triaged Cargo.lock: baz 0.1.0 RUSTSEC-2099-0006 -> no fixed version yet' <<<\"\$out30\" && [ \"\$(tail -1 <<<\"\$out30\")\" = 'database RustSec of 2099-01-01' ] && ! grep -q 'only tests' <<<\"\$out30\""
  # Spaces in `fixed` do not count, and a row holds through its last day.
  row30 RUSTSEC-2099-0005 foo "a key that only verifies" ">=1.2.2" "$(day30 0)" >> docs/advisories.toml
  gate30 --triaged docs/advisories.toml Cargo.lock
  check "with a row for each, the gate lets it through, and session-start says nothing" "[ $rc30 -eq 0 ] && ! grep -q '^untriaged' <<<\"\$out30\" && ! says 'RUST ADVISORIES' u30 session Cargo.lock && says '^  ok    Cargo.lock: no RustSec advisory for its 2 crates beyond the 3 triaged in docs/advisories.toml' u30 doctor Cargo.lock"
  { row30 RUSTSEC-2099-0001 foo x none "$(day30 3)"
    row30 RUSTSEC-2099-0005 foo y ">= 1.2.2" "$(day30 -1)"
    row30 RUSTSEC-2099-0006 baz z none "$(day30 3)"; } > docs/advisories.toml
  s30=$(u30 session Cargo.lock 2>&1); gate30 --triaged docs/advisories.toml Cargo.lock
  check "a row whose day has passed, or whose fixed versions moved, is said again and refused" "grep -q '^=== RUST ADVISORIES (2; ' <<<\"\$s30\" && grep -q 'RUSTSEC-2099-0001, Foo overflows -> fixed in >= 1.2.3; triaged with fixed = \"none\", and RustSec.s fixed versions have moved' <<<\"\$s30\" && grep -q \"RUSTSEC-2099-0005, Foo leaks -> fixed in >= 1.2.2; triaged until $(day30 -1), which has passed\" <<<\"\$s30\" && [ $rc30 -eq 1 ] && grep -q '^changed Cargo.lock: foo 1.2.0 RUSTSEC-2099-0001' <<<\"\$out30\" && grep -q '^expired Cargo.lock: foo 1.2.0 RUSTSEC-2099-0005' <<<\"\$out30\" && grep -q '^triaged Cargo.lock: baz 0.1.0 RUSTSEC-2099-0006' <<<\"\$out30\""
  { row30 RUSTSEC-2099-0001 foo x ">= 1.2.3" "$(day30 91)"
    printf '[[triaged]]\nid = "RUSTSEC-2099-0005"\ncrate = "foo"\nfixed = ">= 1.2.2"\nuntil = %s\n\n' "$(day30 3)"
    row30 RUSTSEC-2099-0006 bar z none "$(day30 3)"; } > docs/advisories.toml
  s30=$(u30 doctor Cargo.lock 2>&1); gate30 --triaged docs/advisories.toml Cargo.lock
  check "a row that cannot count is said with its fault: too far ahead, no why, another crate" "grep -q \"RUSTSEC-2099-0001, .*does not count: its until $(day30 91) is more than 90 days ahead; $(day30 90) at most\" <<<\"\$s30\" && grep -q 'RUSTSEC-2099-0005, .*does not count: it has no why' <<<\"\$s30\" && grep -q 'RUSTSEC-2099-0006, .*does not count: it names the crate bar, and the advisory is about baz' <<<\"\$s30\" && [ $rc30 -eq 1 ] && [ \$(grep -c '^invalid ' <<<\"\$out30\") -eq 3 ]"
  { printf '[[triaged]]\nid = "RUSTSEC-2099-0001"\ncrate = "foo"\nwhy = "x"\nfixed = ">= 1.2.3"\nuntil = "soon"\n\n'
    printf '[[triaged]]\nid = "RUSTSEC-2099-0005"\ncrate = "foo"\nwhy = "y"\nuntil = %s\n\n' "$(day30 3)"; } > docs/advisories.toml
  s30=$(u30 doctor Cargo.lock 2>&1)
  check "and so is one whose day is not a date, or that has no fixed" "grep -q 'RUSTSEC-2099-0001, .*does not count: its until is not a date' <<<\"\$s30\" && grep -q 'RUSTSEC-2099-0005, .*does not count: it has no fixed' <<<\"\$s30\""
  printf 'this is = not [toml\n' > "$tmp/s30-bad.toml"
  gate30 --triaged "$(winpath "$tmp/s30-bad.toml")" Cargo.lock; bad30=$rc30
  gate30 --triaged docs/advisories.toml no/Cargo.lock; nolock30=$rc30
  o30=$(env AI_BACKBONE_ADVISORY_DB="$(winpath "$tmp/s30-none")" "$py" "$root/.ai-backbone/upstream.py" --advisories gate Cargo.lock 2>&1); nodb30=$?
  check "the gate exits 2 when it could not tell: a triage file that is not TOML, a lock it cannot read, no database" "[ $bad30 -eq 2 ] && [ $nolock30 -eq 2 ] && [ $nodb30 -eq 2 ] && grep -q '^error no RustSec database to read' <<<\"\$o30\""
  gate30 --triaged "$(winpath "$tmp/s30-none.toml")" "$(winpath "$tmp/s30-clean.lock")"
  check "and reads a triage file that is not there as an empty list" "[ $rc30 -eq 0 ] && grep -q '^note .*s30-none.toml does not exist, so nothing is triaged' <<<\"\$out30\" && grep -q '^ok .*s30-clean.lock: no advisory for its 1 crate$' <<<\"\$out30\""
  { row30 RUSTSEC-2099-0001 foo x ">= 1.2.3" "$(day30 3)"; row30 RUSTSEC-2099-0005 foo x ">= 1.2.2" "$(day30 3)"
    row30 RUSTSEC-2099-0006 baz x none "$(day30 3)"; } > docs/advisories.toml
  gate30 Cargo.lock; here30=$rc30
  ( cd "$tmp" && u30 gate --triaged "$(winpath "$tmp/s29/docs/advisories.toml")" "$(winpath "$tmp/s29/Cargo.lock")" >/dev/null 2>&1 ); there30=$?
  check "the gate reads only the files it is given, never the docs/ of the folder it runs in" "[ $here30 -eq 1 ] && [ $there30 -eq 0 ]"
  # A copy in the cache, fetched 8 days ago and 3 days ago, with no network.
  xdg30="$tmp/s30-xdg"; mkdir -p "$xdg30/ai-backbone"; cp -R "$tmp/s29-db" "$xdg30/ai-backbone/advisory-db"
  age30() { "$py" -c 'import os, sys, time; t = time.time() - float(sys.argv[2]) * 86400; os.utime(sys.argv[1], (t, t))' "$(winpath "$xdg30/ai-backbone/advisory-db/ai-backbone.fetched")" "$1"; }
  sg30() { env -u AI_BACKBONE_ADVISORY_DB AI_BACKBONE_OFFLINE=1 XDG_CACHE_HOME="$(winpath "$xdg30")" "$py" "$root/.ai-backbone/upstream.py" --advisories gate "$(winpath "$tmp/s30-clean.lock")" 2>&1; }
  age30 8; o30=$(sg30); st30=$?
  age30 3; o3=$(sg30)
  check "a copy fetched over 7 days ago that cannot be fetched again is said stale, and the gate still decides" "[ $st30 -eq 0 ] && grep -q '^stale RustSec database of 2099-01-01, offline (AI_BACKBONE_OFFLINE); the copy here was fetched 8 day(s) ago' <<<\"\$o30\" && grep -q '^database RustSec of 2099-01-01, offline' <<<\"\$o3\""
  # A label for a crate only tests build, read from Cargo.toml, never a
  # silencer (n-3140d5). baz is a renamed workspace dep, old is target-only,
  # foo is a dev-dependency. An edge the reader does not understand labels nothing.
  use30="$tmp/s30-use"; mkdir -p "$use30/app"
  printf '%s\n' '[workspace]' 'members = ["app"]' '[workspace.dependencies]' 'alias = { package = "baz", version = "0.1" }' > "$use30/Cargo.toml"
  printf '%s\n' '[dependencies]' 'alias = { workspace = true }' "[target.'cfg(unix)'.dependencies]" 'old = "0.2"' '[dev-dependencies]' 'foo = "1"' > "$use30/app/Cargo.toml"
  printf 'version = 4\n\n[[package]]\nname = "baz"\nversion = "0.1.0"\nsource = "%s"\ndependencies = [\n "old 0.2.4",\n]\n\n[[package]]\nname = "old"\nversion = "0.2.4"\nsource = "%s"\n\n[[package]]\nname = "foo"\nversion = "1.2.0"\nsource = "%s"\n' "$reg" "$reg" "$reg" > "$use30/Cargo.lock"
  o30=$(u30 doctor "$use30/Cargo.lock" 2>&1); gate30 "$use30/Cargo.lock"
  check "a dev-dependency is labelled only-tests and still warned" "grep -q 'foo 1.2.0 (only tests, by Cargo.toml) has RUSTSEC-2099-0001' <<<\"\$o30\" && grep -q '^  warn  ' <<<\"\$o30\" && grep -q 'foo 1.2.0 (only tests, by Cargo.toml) RUSTSEC-2099-0001' <<<\"\$out30\" && [ $rc30 -eq 1 ]"
  check "a renamed dep and a target dep are not called test-only" "grep -q 'baz 0.1.0 has RUSTSEC-2099-0006' <<<\"\$o30\" && grep -q 'old 0.2.4 has RUSTSEC-2099-0004' <<<\"\$o30\" && ! grep -q 'baz 0.1.0 (only tests' <<<\"\$o30\" && ! grep -q 'old 0.2.4 (only tests' <<<\"\$o30\""
  printf '%s\n' '[dependencies]' 'weird = { optional = true }' '[dev-dependencies]' 'foo = "1"' > "$use30/app/Cargo.toml"
  o30=$(u30 doctor "$use30/Cargo.lock" 2>&1)
  check "an edge the reader does not understand gets no test-only label" "! grep -q 'only tests, by Cargo.toml' <<<\"\$o30\" && grep -q 'foo 1.2.0 has RUSTSEC-2099-0001' <<<\"\$o30\""

  section "a GitHub advisory from OSV (n-87f6a0)"
  # A querybatch answer names only the id and when it changed; the detail comes
  # from /v1/vulns/<id>. Both are files, so the suite never reaches the network.
  osv31="$tmp/s31-osv"; mkdir -p "$osv31/vulns"
  osv31url() { fileurl "$osv31/querybatch"; }
  u31() { env AI_BACKBONE_ADVISORY_DB="$(winpath "$db30")" AI_BACKBONE_OSV_URL="$(osv31url)" \
    "$py" "$root/.ai-backbone/upstream.py" --advisories "$@"; }
  cat > "$osv31/querybatch" <<'JSON'
{"results": [{"vulns": [{"id": "GHSA-m665-v7pm-7grj", "modified": "2026-10-28T15:30:00Z"}]}]}
JSON
  cat > "$osv31/vulns/GHSA-m665-v7pm-7grj" <<'JSON'
{
  "schema_version": "1.7.0",
  "id": "GHSA-m665-v7pm-7grj",
  "modified": "2026-10-28T15:30:00Z",
  "published": "2026-10-28T15:30:00Z",
  "aliases": ["CVE-2026-39804"],
  "summary": "Zip writes a file outside the output folder",
  "details": "### Impact\nA crafted archive can make Zip write outside the folder it extracts into.\n\n### Patched\n9.0.5.",
  "affected": [
    {
      "package": {"ecosystem": "crates.io", "name": "zip", "purl": "pkg:cargo/zip"},
      "ranges": [{"type": "SEMVER", "events": [{"introduced": "0"}, {"fixed": "9.0.5"}]}],
      "database_specific": {"source": "https://github.com/github/advisory-database/blob/main/advisories/github-reviewed/2026/10/GHSA-m665-v7pm-7grj/GHSA-m665-v7pm-7grj.json"}
    }
  ],
  "references": [{"type": "ADVISORY", "url": "https://github.com/rust-lang/zip/security/advisories/GHSA-m665-v7pm-7grj"}],
  "database_specific": {"cwe_ids": ["CWE-22"], "severity": "HIGH", "github_reviewed": true, "github_reviewed_at": "2026-10-28T15:30:00Z", "nvd_published_at": null}
}
JSON
  lock29 zip 8.6.0 "$reg" > Cargo.lock
  doc31=$(u31 doctor Cargo.lock 2>&1)
  check "OSV's GHSA-only advisory is reported with its summary and fixed version" "grep -q '^  warn  Cargo.lock: zip 8.6.0 has GHSA-m665-v7pm-7grj, Zip writes a file outside the output folder -> fixed in >= 9.0.5' <<<\"\$doc31\""
  check "session-start says it too" "s31=\$(u31 session Cargo.lock 2>&1); grep -q '^=== RUST ADVISORIES (1; ' <<<\"\$s31\" && grep -q '^- Cargo.lock: zip 8.6.0 has GHSA-m665-v7pm-7grj' <<<\"\$s31\""
  row30 GHSA-m665-v7pm-7grj zip "only the safe extractor" ">= 9.0.5" "$(day30 3)" > docs/advisories.toml
  gate31=$(u31 gate --triaged docs/advisories.toml Cargo.lock 2>&1); rc31=$?
  check "a row for a GHSA id covers it, and session-start stays quiet" "[ $rc31 -eq 0 ] && grep -q '^triaged Cargo.lock: zip 8.6.0 GHSA-m665-v7pm-7grj -> fixed in >= 9.0.5' <<<\"\$gate31\" && ! says 'RUST ADVISORIES' u31 session Cargo.lock"
  # A GHSA id whose aliases name a RustSec advisory is that older path's, not a
  # second finding from OSV.
  lock29 foo 1.2.0 "$reg" > Cargo.lock
  cat > "$osv31/querybatch" <<'JSON'
{"results": [{"vulns": [{"id": "GHSA-2099-0002", "modified": "2099-01-01T00:00:00Z"}]}]}
JSON
  cat > "$osv31/vulns/GHSA-2099-0002" <<'JSON'
{
  "schema_version": "1.7.0",
  "id": "GHSA-2099-0002",
  "modified": "2099-01-01T00:00:00Z",
  "published": "2099-01-01T00:00:00Z",
  "aliases": ["RUSTSEC-2099-0005"],
  "summary": "The same advisory under another name",
  "details": "RustSec has this one already.",
  "affected": [{"package": {"ecosystem": "crates.io", "name": "foo", "purl": "pkg:cargo/foo"},
    "ranges": [{"type": "SEMVER", "events": [{"introduced": "0"}, {"fixed": "1.2.2"}]}]}],
  "references": [{"type": "ADVISORY", "url": "https://example.invalid/GHSA-2099-0002"}],
  "database_specific": {"severity": "HIGH"}
}
JSON
  doc31=$(u31 doctor Cargo.lock 2>&1)
  check "an OSV id with a RUSTSEC alias is not added" "! grep -q 'GHSA-2099-0002' <<<\"\$doc31\" && grep -q 'RUSTSEC-2099-0005' <<<\"\$doc31\""
  # An informational RUSTSEC id from OSV is the RustSec path's to leave out.
  lock29 paste 1.0.0 "$reg" > Cargo.lock
  cat > "$osv31/querybatch" <<'JSON'
{"results": [{"vulns": [{"id": "RUSTSEC-2024-0436", "modified": "2024-02-01T00:00:00Z"}]}]}
JSON
  doc31=$(u31 doctor Cargo.lock 2>&1)
  check "an informational RUSTSEC from OSV is not added" "! grep -q 'RUSTSEC-2024-0436' <<<\"\$doc31\" && grep -q '^  ok    Cargo.lock: no RustSec advisory for its 1 crate' <<<\"\$doc31\""
  # A GHSA alias of a triaged RustSec row asks for no second row.
  lock29 foo 1.2.0 "$reg" > Cargo.lock
  cat > "$osv31/querybatch" <<'JSON'
{"results": [{"vulns": [{"id": "GHSA-2099-0003", "modified": "2099-01-01T00:00:00Z"}]}]}
JSON
  cat > "$osv31/vulns/GHSA-2099-0003" <<'JSON'
{
  "schema_version": "1.7.0",
  "id": "GHSA-2099-0003",
  "modified": "2099-01-01T00:00:00Z",
  "published": "2099-01-01T00:00:00Z",
  "aliases": ["RUSTSEC-2099-0001"],
  "summary": "A GitHub name for a RustSec advisory",
  "details": "RustSec has this one already.",
  "affected": [{"package": {"ecosystem": "crates.io", "name": "foo", "purl": "pkg:cargo/foo"},
    "ranges": [{"type": "SEMVER", "events": [{"introduced": "0"}, {"fixed": "1.2.3"}]}]}],
  "references": [{"type": "ADVISORY", "url": "https://example.invalid/GHSA-2099-0003"}],
  "database_specific": {"severity": "HIGH"}
}
JSON
  { row30 RUSTSEC-2099-0001 foo x ">= 1.2.3" "$(day30 3)"
    row30 RUSTSEC-2099-0005 foo y ">= 1.2.2" "$(day30 3)"; } > docs/advisories.toml
  gate31=$(u31 gate --triaged docs/advisories.toml Cargo.lock 2>&1); rc31=$?
  check "a GHSA alias of a triaged RUSTSEC row is not asked" "[ $rc31 -eq 0 ] && ! grep -q 'GHSA-2099-0003' <<<\"\$gate31\" && ! says 'RUST ADVISORIES' u31 session Cargo.lock"
  # No answer at all is one line, and RustSec is still read.
  down31=$(env AI_BACKBONE_ADVISORY_DB="$(winpath "$db30")" AI_BACKBONE_OSV_URL="$(fileurl "$osv31/missing/querybatch")" \
    "$py" "$root/.ai-backbone/upstream.py" --advisories doctor "$(winpath "$tmp/s30-clean.lock")" 2>&1)
  sdown31=$(env AI_BACKBONE_ADVISORY_DB="$(winpath "$db30")" AI_BACKBONE_OSV_URL="$(fileurl "$osv31/missing/querybatch")" \
    "$py" "$root/.ai-backbone/upstream.py" --advisories session "$(winpath "$tmp/s30-clean.lock")" 2>&1)
  check "OSV down is said once, and RustSec is still read" "[ \$(grep -c 'OSV could not be read' <<<\"\$down31\") -eq 1 ] && grep -q 'no RustSec advisory' <<<\"\$down31\" && grep -qx 'OSV could not be read' <<<\"\$sdown31\""
  rm -f docs/advisories.toml
else
  check "without tomllib, the gate says it could not tell" "o=\$(\"\$py\" \"\$root/.ai-backbone/upstream.py\" --advisories gate Cargo.lock 2>&1); [ \$? -eq 2 ] && grep -q '^error needs Python 3.11' <<<\"\$o\""
fi
cd "$tmp" || exit 1

# n-67104d: the file on disk is the checkout. The running justfile is the one
# that has delegate, and it names that command. It does not write the file.
oldbb=$tmp/old-bb
rm -rf "$oldbb"
mkdir -p "$oldbb/.ai-backbone"
git -C "$oldbb" init -qb main
git -C "$oldbb" config user.email "old@example.com"
git -C "$oldbb" config user.name "Old"
git -C "$oldbb" config commit.gpgsign false
printf 'version 3.0.0\n\nhelp:\n    @echo hi\n' > "$oldbb/.ai-backbone/core.just"
printf 'seed\n' > "$oldbb/README.md"
git -C "$oldbb" add README.md .ai-backbone/core.just
git -C "$oldbb" commit -qm "chore: old"
check "an older core.just is told the delegate command, by session-start and by doctor" \
  "says 'no delegate recipe' just -f '$root/Justfile' -d '$oldbb' _delegate-fallback && says --justfile just -f '$root/Justfile' -d '$oldbb' _delegate-fallback && says --working-directory just -f '$root/Justfile' -d '$oldbb' _delegate-fallback && says 'core\\.just' just -f '$root/Justfile' -d '$oldbb' _delegate-fallback && says 'no delegate recipe' just -f '$root/Justfile' -d '$oldbb' session-start && says 'no delegate recipe' just -f '$root/Justfile' -d '$oldbb' doctor"
check "a checkout whose core.just has delegate is not given that line" \
  "! says 'no delegate recipe|error:' just -f '$root/Justfile' -d '$root' _delegate-fallback && printf '\ndelegate task=\"\":\n    @true\n' >> '$oldbb/.ai-backbone/core.just' && ! says 'no delegate recipe|error:' just -f '$root/Justfile' -d '$oldbb' _delegate-fallback"
check "a folder with no core.just is not called an older delegate" \
  "rm -f '$oldbb/.ai-backbone/core.just' && ! says 'no delegate recipe|error:' just -f '$root/Justfile' -d '$oldbb' _delegate-fallback"

fi
if lane_wants delegate; then
section "delegate (spec 034)"
# Its own process on Windows never ran the budget, so the stand-in is here too.
install_audit_standin
# The recipe's text is in d_out. The shared check prints the eval's own
# stdout, which this section leaves empty, so a red line had nothing under
# it (windows-latest, run 39407850519). Show what the recipe printed.
check() {
  : > "$tmp/check.out"; : > "$tmp/says.out"
  if eval "$2" >"$tmp/check.out" 2>&1; then ok "$1"; else bad "$1"
    if [ -s "$tmp/check.out" ] || [ -s "$tmp/says.out" ]; then cat "$tmp/check.out" "$tmp/says.out"; else printf '%s\n' "${out:-}"; fi | tail -12 | sed 's/^/        /'
    if [ -n "${d_out-}" ]; then printf '%s\n' "$d_out" | sed -n '1,30s/^/        | /p'
    else printf '%s\n' '        | (no recipe output)'; fi
  fi
}
# A script stands in for the worker. The recipes call the resolved path; on
# PATH that is this script. It records the prompt and does what FAKE_WORKER_MODE
# says. FAKE_WORKER_BINLOG, when set, receives the path the recipe executed.
dhome="$tmp/delegate-home"
dbin="$tmp/delegate-bin"
dprompt="$tmp/delegate-prompt"
dgo="$tmp/delegate-go"
mkdir -p "$dbin" "$dhome"
cat > "$dbin/grok" << 'EOF'
#!/usr/bin/env bash
prompt=""
fmt=""
model=""
perm=""
deny=""
sandbox=""
trust=""
web=no
while [ $# -gt 0 ]; do
  case "$1" in
    -p) prompt=$2; shift 2 ;;
    --output-format) fmt=$2; shift 2 ;;
    --model) model=$2; shift 2 ;;
    --permission-mode) perm=$2; shift 2 ;;
    --background-wait-timeout) bgwait=$2; shift 2 ;;
    --sandbox) sandbox=$2; shift 2 ;;
    --trust) trust=yes; shift ;;
    --disable-web-search) web=yes; shift ;;
    --deny) deny="$deny$2
"; shift 2 ;;
    --rules|--allow) shift 2 ;;
    *) echo "unexpected: $1" >&2; exit 2 ;;
  esac
done
if [ -n "${FAKE_WORKER_PROMPT:-}" ]; then
  printf '%s\n' "$prompt" > "$FAKE_WORKER_PROMPT"
  printf '%s\n' "$fmt" > "$FAKE_WORKER_PROMPT.fmt"
  printf '%s\n' "$model" > "$FAKE_WORKER_PROMPT.model"
  printf '%s\n' "$perm" > "$FAKE_WORKER_PROMPT.perm"
  printf '%s\n' "$bgwait" > "$FAKE_WORKER_PROMPT.bgwait"
  printf '%s\n' "$sandbox" > "$FAKE_WORKER_PROMPT.sandbox"
  printf '%s\n' "${trust:-no}" > "$FAKE_WORKER_PROMPT.grok-trust"
  printf '%s\n' "$web" > "$FAKE_WORKER_PROMPT.web"
  if [ -f .grok/config.toml ]; then cp .grok/config.toml "$FAKE_WORKER_PROMPT.mcp"
  else : > "$FAKE_WORKER_PROMPT.mcp"; fi
  printf '%s' "$deny" > "$FAKE_WORKER_PROMPT.deny"
  if [ -n "${RUSTC_WRAPPER+x}" ]; then printf '%s\n' "$RUSTC_WRAPPER" > "$FAKE_WORKER_PROMPT.rustc-wrapper"
  else printf '%s\n' unset > "$FAKE_WORKER_PROMPT.rustc-wrapper"; fi
  if [ -n "${SCCACHE_SERVER_UDS+x}" ]; then printf '%s\n' "$SCCACHE_SERVER_UDS" > "$FAKE_WORKER_PROMPT.sccache-uds"
  else printf '%s\n' unset > "$FAKE_WORKER_PROMPT.sccache-uds"; fi
  printf '%s\n' "${SCCACHE_SERVER_PORT:-}" > "$FAKE_WORKER_PROMPT.sccache-port"
fi
if [ -n "${FAKE_WORKER_BINLOG:-}" ]; then printf '%s\n' "$0" > "$FAKE_WORKER_BINLOG"; fi
mode=${FAKE_WORKER_MODE:-ok}
case "$mode" in
  ok)
    printf 'done\n' > worker-did.txt
    git add worker-did.txt
    git commit -qm "chore: worker did the task" --no-verify
    n=1
    while [ "$n" -le 20 ]; do printf 'line-%02d\n' "$n"; n=$((n+1)); done
    ;;
  sign)
    printf 'signed\n' > worker-signed.txt
    git add worker-signed.txt
    git commit -qm "chore: worker signed the task"
    printf 'worker signed the task\n'
    ;;
  sandboxedit)
    printf '\n# worker changed the profile\n' >> .grok/sandbox.toml
    echo report
    ;;
  slow)
    echo started
    i=0
    while [ "$i" -lt 100 ]; do
      [ -n "${FAKE_WORKER_GO:-}" ] && [ -f "$FAKE_WORKER_GO" ] && break
      i=$((i+1))
      sleep 0.2
    done
    echo report
    ;;
  dirty)
    echo report
    echo x > left-dirty.txt
    ;;
  fail)
    echo report
    exit 3
    ;;
  push)
    printf 'pushed\n' > worker-did.txt
    git add worker-did.txt
    git commit -qm "chore: worker did the task" --no-verify
    git push -q origin HEAD
    br=$(git symbolic-ref --short HEAD)
    git update-ref -d "refs/remotes/origin/$br" 2>/dev/null || true
    echo report
    ;;
  fetch)
    url=$(git remote get-url origin)
    side=$(mktemp -d)
    # -b main: a bare repo's HEAD may not be main, and a clone of that
    # refuses to check out. The new commit has to sit on top of main or the
    # push is not a fast-forward and origin/main never moves.
    git clone -q -b main "$url" "$side"
    git -C "$side" config user.email "delegate-test@example.com"
    git -C "$side" config user.name "Delegate Test"
    git -C "$side" config commit.gpgsign false
    printf 'from-elsewhere\n' >> "$side/README.md"
    git -C "$side" add README.md
    git -C "$side" commit -qm "chore: elsewhere moved main" --no-verify
    git -C "$side" push -q origin HEAD:main
    # No refspec on the command line: that is what moves origin/main.
    # `git fetch origin main` writes FETCH_HEAD only (git 2.56).
    git fetch -q origin
    rm -rf "$side"
    echo report
    ;;
  third)
    url=$(git remote get-url origin)
    side=$(mktemp -d)
    git clone -q "$url" "$side"
    git -C "$side" config user.email "delegate-test@example.com"
    git -C "$side" config user.name "Delegate Test"
    git -C "$side" config commit.gpgsign false
    git -C "$side" checkout -q -b unrelated
    printf 'unrelated\n' > "$side/other.txt"
    git -C "$side" add other.txt
    git -C "$side" commit -qm "chore: a third party" --no-verify
    git -C "$side" push -q origin unrelated
    rm -rf "$side"
    echo report
    ;;
  move)
    git checkout -q main
    printf 'moved\n' >> README.md
    git add README.md
    git commit -qm "chore: moved the default branch" --no-verify
    echo report
    ;;
  branch)
    git branch from-the-worker
    echo report
    ;;
  othersess)
    # n-dbc9e9: another session in this repository, not this worktree's hook.
    git -c core.hooksPath=/dev/null branch delegate/other-session
    echo report
    ;;
  sibling)
    # A parallel lane: another worktree of this repository creates its own
    # branch while this run is going.
    git worktree add -q -b lane/parallel "$FAKE_WORKER_SIDE"
    echo report
    ;;
  siblingdrop)
    # Another worktree drops its own branch while this run is going.
    git worktree remove --force "$FAKE_WORKER_SIDE"
    git branch -D lane/old >/dev/null
    echo report
    ;;
  fix)
    printf 'fixed\n' >> worker-did.txt
    git add worker-did.txt
    git commit -qm "chore: worker fixed the task" --no-verify
    echo report
    ;;
  movebase)
    target=${FAKE_WORKER_TARGET:-main}
    git checkout -q "$target"
    printf 'moved\n' >> README.md
    git add README.md
    git commit -qm "chore: moved the base branch" --no-verify
    echo report
    ;;
  timeout)
    echo report
    sleep 30
    echo finished
    ;;
  idle)
    printf 'done\n' > worker-did.txt
    git add worker-did.txt
    git commit -qm "chore: worker did the task" --no-verify
    echo report
    exec perl -e 'sleep 60'
    ;;
  idledirty)
    printf 'done\n' > worker-did.txt
    git add worker-did.txt
    git commit -qm "chore: worker did the task" --no-verify
    echo x > left-dirty.txt
    exec perl -e 'sleep 18'
    ;;
  idlewindow)
    printf 'done\n' > worker-did.txt
    git add worker-did.txt
    git commit -qm "chore: worker did the task" --no-verify
    echo x > left-dirty.txt
    exec perl -e 'sleep 8; unlink "left-dirty.txt"; sleep 40'
    ;;
  quiet)
    echo report
    exec perl -e 'sleep 12'
    ;;
  laneown)
    git branch lane/sneak
    echo report
    ;;
  merge)
    printf 'base\n' >> README.md
    git add README.md
    git commit -qm "chore: base" --no-verify
    other=$(git commit-tree "HEAD^{tree}" -p "HEAD^" -m other)
    git merge --no-edit -m "merge other" "$other" || true
    echo report
    ;;
  stdin)
    # A CLI that reads its input until the end before it exits.
    cat >/dev/null
    echo report
    ;;
  hookwt)
    # n-154b76: this worktree's hooksPath is the job's. The sibling keeps the
    # common one, so a merge there is allowed. A merge here is still refused.
    printf '%s\n' "$(git config --get core.hooksPath || true)" > "$FAKE_WORKER_PROMPT.here-hooks"
    printf '%s\n' "$(git -C "$FAKE_WORKER_SIDE" config --get core.hooksPath || true)" > "$FAKE_WORKER_PROMPT.side-hooks"
    printf 'lane\n' >> "$FAKE_WORKER_SIDE/README.md"
    git -C "$FAKE_WORKER_SIDE" add README.md
    git -C "$FAKE_WORKER_SIDE" commit -qm "chore: lane" --no-verify
    base=$(git -C "$FAKE_WORKER_SIDE" rev-parse HEAD^)
    other=$(git -C "$FAKE_WORKER_SIDE" commit-tree "${base}^{tree}" -p "$base" -m other)
    if git -C "$FAKE_WORKER_SIDE" merge --no-ff --no-edit -m "merge other" "$other"; then
      echo side-merge-ok > "$FAKE_WORKER_PROMPT.side-merge"
    else
      echo side-merge-fail > "$FAKE_WORKER_PROMPT.side-merge"
    fi
    if git merge --no-ff --no-edit -m "merge other" "$other"; then
      echo worker-merge-ok > "$FAKE_WORKER_PROMPT.worker-merge"
    else
      echo worker-merge-fail > "$FAKE_WORKER_PROMPT.worker-merge"
    fi
    git merge --abort >/dev/null 2>&1 || true
    echo report
    ;;
  *) echo "unknown mode $mode" >&2; exit 2 ;;
esac
EOF
cp "$dbin/grok" "$dbin/claude"
chmod +x "$dbin/grok" "$dbin/claude"
# opencode's argv is `run --standalone --auto --format json -m <model> <prompt>`,
# not grok's -p flags. A copy of the grok fake would exit 2 on `run`.
cat > "$dbin/opencode" << 'OCEOF'
#!/usr/bin/env bash
# Stands in for `opencode run`. Records the argv and OPENCODE_CONFIG the
# adapter passed, and prints --format json events. No model is called.
# n-20e061: delegate-status asks `service status` and must not start a run.
if [ "${1:-}" = service ] && [ "${2:-}" = status ]; then
  printf '%s\n' "${FAKE_OPENCODE_STATUS:-stopped}"
  exit 0
fi
if [ -n "${FAKE_WORKER_BINLOG:-}" ]; then printf '%s\n' "$0" > "$FAKE_WORKER_BINLOG"; fi
if [ -n "${FAKE_WORKER_PROMPT:-}" ]; then printf '%s\n' "$@" > "$FAKE_WORKER_PROMPT.argv"; fi
if [ "${1:-}" != run ]; then echo "unexpected: ${1:-}" >&2; exit 2; fi
shift
standalone=""
auto=""
fmt=""
model=""
prompt=""
while [ $# -gt 0 ]; do
  case "$1" in
    --standalone) standalone=1; shift ;;
    --auto) auto=1; shift ;;
    --format) fmt=$2; shift 2 ;;
    -m) model=$2; shift 2 ;;
    --) shift; break ;;
    -*) echo "unexpected: $1" >&2; exit 2 ;;
    *)
      if [ -n "$prompt" ]; then echo "unexpected: $1" >&2; exit 2; fi
      prompt=$1; shift ;;
  esac
done
if [ $# -gt 0 ]; then echo "unexpected: $1" >&2; exit 2; fi
if [ -z "$standalone" ] || [ -z "$auto" ] || [ -z "$fmt" ] || [ -z "$model" ] || [ -z "$prompt" ]; then
  echo "unexpected: incomplete run" >&2; exit 2
fi
if [ -n "${FAKE_WORKER_PROMPT:-}" ]; then
  printf '%s\n' "$prompt" > "$FAKE_WORKER_PROMPT"
  printf '%s\n' "$fmt" > "$FAKE_WORKER_PROMPT.fmt"
  printf '%s\n' "$model" > "$FAKE_WORKER_PROMPT.model"
  printf '%s\n' "$standalone" > "$FAKE_WORKER_PROMPT.standalone"
  printf '%s\n' "$auto" > "$FAKE_WORKER_PROMPT.auto"
  printf '%s\n' "${OPENCODE_CONFIG:-}" > "$FAKE_WORKER_PROMPT.configpath"
  if [ -n "${OPENCODE_CONFIG:-}" ] && [ -f "$OPENCODE_CONFIG" ]; then
    cp "$OPENCODE_CONFIG" "$FAKE_WORKER_PROMPT.config"
  else
    : > "$FAKE_WORKER_PROMPT.config"
  fi
  printf '%s\n' "${OPENCODE_CONFIG_PROJECT_DISABLE:-}" > "$FAKE_WORKER_PROMPT.projectdisable"
  printf '%s\n' "$model" >> "$FAKE_WORKER_PROMPT.models"
fi
mode=${FAKE_WORKER_MODE:-ok}
case "$mode" in
  ok|fix)
    # A text event carries a cost the sum must ignore. Two step_finish
    # events are 0.01 and 0.02.
    printf '%s\n' '{"type":"text","part":{"cost":9}}'
    printf '%s\n' '{"type":"step_finish","timestamp":1,"sessionID":"s","part":{"type":"step-finish","cost":0.01,"tokens":{"input":1,"output":1}}}'
    printf '%s\n' '{"type":"step_finish","timestamp":2,"sessionID":"s","part":{"type":"step-finish","cost":0.02,"tokens":{"input":1,"output":1}}}'
    if [ "$mode" = ok ]; then
      printf 'done\n' > worker-did.txt
      git add worker-did.txt
      git commit -qm "chore: worker did the task" --no-verify
    else
      printf 'fixed\n' >> worker-did.txt
      git add worker-did.txt
      git commit -qm "chore: worker fixed the task" --no-verify
    fi
    echo report
    ;;
  fail)
    echo report
    exit 3
    ;;
  timeout)
    echo report
    sleep 30
    echo finished
    ;;
  *) echo "unknown mode $mode" >&2; exit 2 ;;
esac
OCEOF
chmod +x "$dbin/opencode"
# kimi's argv is `-p <prompt> --output-format stream-json` and `-m` when
# DELEGATE_MODEL is set. A copy of the grok fake would reject --output-format
# only after -p, but it also rejects nothing we need; its flag set is not
# kimi's, and it would not print stream-json. No model is called.
cat > "$dbin/kimi" << 'KIEOF'
#!/usr/bin/env bash
if [ -n "${FAKE_WORKER_BINLOG:-}" ]; then printf '%s\n' "$0" > "$FAKE_WORKER_BINLOG"; fi
if [ -n "${FAKE_WORKER_PROMPT:-}" ]; then printf '%s\n' "$@" > "$FAKE_WORKER_PROMPT.argv"; fi
prompt=""
fmt=""
model=""
while [ $# -gt 0 ]; do
  case "$1" in
    -p) prompt=$2; shift 2 ;;
    --output-format) fmt=$2; shift 2 ;;
    -m) model=$2; shift 2 ;;
    --yolo|--auto|--plan) echo "unexpected: $1" >&2; exit 2 ;;
    *) echo "unexpected: $1" >&2; exit 2 ;;
  esac
done
if [ -z "$prompt" ] || [ "$fmt" != stream-json ]; then
  echo "unexpected: incomplete" >&2; exit 2
fi
if [ -n "${FAKE_WORKER_PROMPT:-}" ]; then
  printf '%s\n' "$prompt" > "$FAKE_WORKER_PROMPT"
  printf '%s\n' "$fmt" > "$FAKE_WORKER_PROMPT.fmt"
  printf '%s\n' "$model" > "$FAKE_WORKER_PROMPT.model"
  printf '%s\n' "${KIMI_CODE_TRUST_WORKSPACE:-}" > "$FAKE_WORKER_PROMPT.trust"
  printf '%s\n' "${KIMI_CODE_DANGEROUS_COMMAND_GUARD:-}" > "$FAKE_WORKER_PROMPT.guard"
  if [ -n "${KIMI_CODE_HOME+x}" ]; then printf '%s\n' "$KIMI_CODE_HOME" > "$FAKE_WORKER_PROMPT.home"
  else printf '%s\n' unset > "$FAKE_WORKER_PROMPT.home"; fi
  cfg="${KIMI_CODE_HOME:-$HOME/.kimi-code}/config.toml"
  printf '%s\n' "$cfg" > "$FAKE_WORKER_PROMPT.configpath"
  if [ -f "$cfg" ]; then cp "$cfg" "$FAKE_WORKER_PROMPT.config"; else : > "$FAKE_WORKER_PROMPT.config"; fi
fi
mode=${FAKE_WORKER_MODE:-ok}
case "$mode" in
  ok|fix)
    perl -MJSON::PP -e '
      my $content = join("\n", map { sprintf("line-%02d", $_) } 1..20) . "\n";
      my $j = JSON::PP->new->utf8->canonical;
      print $j->encode({role => "assistant", content => $content}), "\n";
      print $j->encode({role => "tool", tool_call_id => "t1", content => "tool-line-should-not-be-the-report\n"}), "\n";
      print $j->encode({role => "meta", type => "system.version"}), "\n";
    '
    if [ "$mode" = ok ]; then
      printf 'done\n' > worker-did.txt
      git add worker-did.txt
      git commit -qm "chore: worker did the task" --no-verify
    else
      printf 'fixed\n' >> worker-did.txt
      git add worker-did.txt
      git commit -qm "chore: worker fixed the task" --no-verify
    fi
    ;;
  *) echo "unknown mode $mode" >&2; exit 2 ;;
esac
KIEOF
chmod +x "$dbin/kimi"
d_new() {
  dproj="$tmp/delegate-$1"
  rm -rf "$dproj"
  mkdir -p "$dproj"
  git -C "$dproj" init -qb main
  git -C "$dproj" config user.email "delegate-test@example.com"
  git -C "$dproj" config user.name "Delegate Test"
  git -C "$dproj" config commit.gpgsign false
  printf 'seed\n' > "$dproj/README.md"
  git -C "$dproj" add README.md
  git -C "$dproj" commit -qm "chore: init"
  rm -f "$dgo" "$dprompt" "$dprompt.fmt" "$dprompt.model" \
    "$dprompt.standalone" "$dprompt.auto" "$dprompt.configpath" \
    "$dprompt.config" "$dprompt.projectdisable" "$dprompt.models" \
    "$dprompt.argv" "$dprompt.perm" "$dprompt.bgwait" \
    "$dprompt.trust" "$dprompt.guard" "$dprompt.home" \
    "$dprompt.rustc-wrapper" "$dprompt.sccache-uds" "$dprompt.sccache-port" \
    "$dprompt.sccache-argv" "$dprompt.sccache-stopped-port" "$dprompt.sccache-stop-uds" \
    "$dprompt.grok-trust" "$dprompt.mcp"
}
# d_run MODE WORKER WORKER_MODEL -- just args. An empty WORKER is unset.
d_run() {
  local mode="$1" worker="$2" model="$3"; shift 3
  # shellcheck disable=SC2086
  d_out=$(env -u WORKER -u WORKER_MODEL -u DELEGATE_TIMEOUT -u DELEGATE_IDLE -u WORKER_BIN -u DELEGATE_BASE -u DELEGATE_YES -u FAKE_WORKER_TARGET \
    -u WORKER_LADDER -u OPENCODE_CONFIG -u OPENCODE_CONFIG_PROJECT_DISABLE \
    -u DELEGATE_MODEL -u KIMI_CODE_HOME -u KIMI_CODE_TRUST_WORKSPACE -u KIMI_CODE_DANGEROUS_COMMAND_GUARD \
    HOME="$dhome" PATH="$dbin:$PATH" \
    FAKE_WORKER_PROMPT="$dprompt" FAKE_WORKER_MODE="$mode" FAKE_WORKER_GO="$dgo" \
    ${worker:+WORKER=$worker} ${model:+WORKER_MODEL=$model} \
    ${WORKER_BIN:+WORKER_BIN=$WORKER_BIN} \
    ${DELEGATE_BASE:+DELEGATE_BASE=$DELEGATE_BASE} \
    ${DELEGATE_YES:+DELEGATE_YES=$DELEGATE_YES} \
    ${FAKE_WORKER_TARGET:+FAKE_WORKER_TARGET=$FAKE_WORKER_TARGET} \
    ${WORKER_LADDER+WORKER_LADDER="$WORKER_LADDER"} \
    ${DELEGATE_MODEL+DELEGATE_MODEL="$DELEGATE_MODEL"} \
    just -f "$root/Justfile" -d "$dproj" "$@" 2>&1) && d_rc=0 || d_rc=$?
  # just names a setpgid it could not do. A seatbelt denies it, and that line
  # is the runner's, not the recipe's report (measured where setpgid is refused).
  local kept="" line
  while IFS= read -r line; do
    case "$line" in
      *child\ setpgid*) continue ;;
      *'LF will be replaced by CRLF'*) continue ;;
    esac
    kept="$kept$line"$'\n'
  done <<< "$d_out"
  d_out=${kept%$'\n'}
}
# Git for Windows may store a hooksPath as D:/... when the suite wrote /d/...
samepath() {
  local a=$1 b=$2 ua ub
  [ "$a" = "$b" ] && return 0
  if [ -z "$a" ] || [ -z "$b" ]; then return 1; fi
  if command -v cygpath >/dev/null 2>&1; then
    ua=$(cygpath -u "$a" 2>/dev/null || printf '%s' "$a")
    ub=$(cygpath -u "$b" 2>/dev/null || printf '%s' "$b")
    [ "$ua" = "$ub" ] && return 0
  fi
  return 1
}
d_one() {
  local n=0 line
  while IFS= read -r line; do [ -n "$line" ] && n=$((n+1)); done <<EOF
$d_out
EOF
  [ "$n" -eq 1 ]
}
d_new off
d_run ok "" "" delegate "add a line"
check "with WORKER unset, delegate says so in one line and makes no branch" "[ \$d_rc -ne 0 ] && d_one && grep -q 'delegation is off (WORKER is unset)' <<<\"\$d_out\" && [ -z \"\$(git -C \"\$dproj\" branch --list 'delegate/*')\" ]"
d_run ok off "" delegate "add a line"
check "with WORKER=off, delegate says so and makes no branch" "[ \$d_rc -ne 0 ] && grep -q 'delegation is off (WORKER=off)' <<<\"\$d_out\" && [ -z \"\$(git -C \"\$dproj\" branch --list 'delegate/*')\" ]"
d_run ok glm "" delegate "add a line"
check "an unknown worker is refused with the list this recipe knows" "[ \$d_rc -ne 0 ] && d_one && grep -qx \"refuses: unknown worker 'glm' (known: claude, grok, opencode, kimi)\" <<<\"\$d_out\""
d_plain="$(dirname "$(command -v just)"):$(dirname "$(command -v git)"):/usr/bin:/bin"
d_out=$(env -u WORKER -u WORKER_BIN HOME="$dhome" PATH="$d_plain" \
  WORKER=grok just -f "$root/Justfile" -d "$dproj" delegate "add a line" 2>&1) && d_rc=0 || d_rc=$?
check "a worker that is not installed is refused in one line" "[ \$d_rc -ne 0 ] && d_one && grep -qx 'refuses: grok is not installed' <<<\"\$d_out\""
d_new found
mkdir -p "$dhome/.grok/bin"
cp "$dbin/grok" "$dhome/.grok/bin/grok"
chmod +x "$dhome/.grok/bin/grok"
rm -f "$tmp/delegate-binlog"
d_out=$(env -u WORKER -u WORKER_BIN HOME="$dhome" PATH="$d_plain" \
  FAKE_WORKER_PROMPT="$dprompt" FAKE_WORKER_MODE=ok FAKE_WORKER_BINLOG="$tmp/delegate-binlog" \
  WORKER=grok just -f "$root/Justfile" -d "$dproj" delegate "add a line" 2>&1) && d_rc=0 || d_rc=$?
check "a grok that lives only at ~/.grok/bin/grok is the binary the adapter runs" \
  "[ \$d_rc -eq 0 ] && [ \"\$(cat \"\$tmp/delegate-binlog\")\" = \"\$dhome/.grok/bin/grok\" ] && [ -f \"\$dproj/worker-did.txt\" ] && [ \"\$(cat \"\$dprompt.fmt\")\" = plain ]"
rm -f "$dhome/.grok/bin/grok"
d_new foundc
mkdir -p "$dhome/.claude/local" "$dhome/.local/bin"
cp "$dbin/claude" "$dhome/.claude/local/claude"
cp "$dbin/claude" "$dhome/.local/bin/claude"
chmod +x "$dhome/.claude/local/claude" "$dhome/.local/bin/claude"
rm -f "$tmp/delegate-binlog"
d_out=$(env -u WORKER -u WORKER_BIN -u WORKER_MODEL HOME="$dhome" PATH="$d_plain" \
  FAKE_WORKER_PROMPT="$dprompt" FAKE_WORKER_MODE=ok FAKE_WORKER_BINLOG="$tmp/delegate-binlog" \
  WORKER=claude just -f "$root/Justfile" -d "$dproj" delegate "use claude" 2>&1) && d_rc=0 || d_rc=$?
check "claude is taken from ~/.claude/local/claude before ~/.local/bin/claude" \
  "[ \$d_rc -eq 0 ] && [ \"\$(cat \"\$tmp/delegate-binlog\")\" = \"\$dhome/.claude/local/claude\" ] && [ -z \"\$(cat \"\$dprompt.fmt\")\" ]"
rm -f "$dhome/.claude/local/claude"
rm -f "$tmp/delegate-binlog"
d_new foundc2
d_out=$(env -u WORKER -u WORKER_BIN -u WORKER_MODEL HOME="$dhome" PATH="$d_plain" \
  FAKE_WORKER_PROMPT="$dprompt" FAKE_WORKER_MODE=ok FAKE_WORKER_BINLOG="$tmp/delegate-binlog" \
  WORKER=claude just -f "$root/Justfile" -d "$dproj" delegate "use claude" 2>&1) && d_rc=0 || d_rc=$?
check "claude falls through to ~/.local/bin/claude when the first place is empty" \
  "[ \$d_rc -eq 0 ] && [ \"\$(cat \"\$tmp/delegate-binlog\")\" = \"\$dhome/.local/bin/claude\" ]"
rm -f "$dhome/.local/bin/claude"
d_new binover
cp "$dbin/grok" "$tmp/only-via-worker-bin"
chmod +x "$tmp/only-via-worker-bin"
rm -f "$tmp/delegate-binlog"
WORKER_BIN="$tmp/only-via-worker-bin" FAKE_WORKER_BINLOG="$tmp/delegate-binlog" d_run ok grok "" delegate "add a line"
# $0 can be another spelling of the same file: Git Bash rewrites WORKER_BIN
# on the way into native just.exe, and cygpath writes it back (the run above).
# Compare the file, not the characters. bash 3.2's test -ef is the same file.
same_bin() {
  a=$1; b=$2
  if command -v cygpath >/dev/null 2>&1; then
    a=$(cygpath -u "$a")
    b=$(cygpath -u "$b")
  fi
  [ "$a" -ef "$b" ]
}
check "WORKER_BIN is the binary, ahead of the name on PATH" \
  "[ \$d_rc -eq 0 ] && same_bin \"\$(cat \"\$tmp/delegate-binlog\")\" \"\$tmp/only-via-worker-bin\""
# Git Bash is not on this machine. A cygpath ahead of PATH is the one the
# recipe calls, and it answers with the real file. A Windows-shaped value
# is not executable until that answer replaces it: without the call, this
# refuses with "not installed" (the same run).
cat > "$dbin/cygpath" << EOF
#!/usr/bin/env bash
printf '%s\n' "$tmp/only-via-worker-bin"
EOF
chmod +x "$dbin/cygpath"
d_new binwin
rm -f "$tmp/delegate-binlog"
WORKER_BIN='C:\Users\runner\AppData\Local\Temp\only-via-worker-bin' FAKE_WORKER_BINLOG="$tmp/delegate-binlog" d_run ok grok "" delegate "add a line"
check "a Windows path in WORKER_BIN is the same binary once cygpath reads it" \
  "[ \$d_rc -eq 0 ] && same_bin \"\$(cat \"\$tmp/delegate-binlog\")\" \"\$tmp/only-via-worker-bin\""
rm -f "$dbin/cygpath"
d_new dirty
printf 'x\n' >> "$dproj/README.md"
d_run ok grok "" delegate "add a line"
check "a dirty tree is refused in one line, before any branch" "[ \$d_rc -ne 0 ] && d_one && grep -qx 'refuses: the working tree is not clean' <<<\"\$d_out\" && [ -z \"\$(git -C \"\$dproj\" branch --list 'delegate/*')\" ]"
d_new branch
git -C "$dproj" checkout -qb other
d_run ok grok "" delegate "add a line"
check "a branch other than the default is refused in one line" "[ \$d_rc -ne 0 ] && d_one && grep -q 'refuses: not on the default branch' <<<\"\$d_out\" && grep -q 'other' <<<\"\$d_out\" && grep -q 'main' <<<\"\$d_out\""
d_new clean
d_run ok grok "" delegate "add a line"
dbr=$(git -C "$dproj" symbolic-ref --short HEAD)
dlog=""
for f in "$dhome/.cache/ai-backbone/delegate/delegate-clean"/*.log; do
  [ -f "$f" ] || continue
  dlog=$f
done
check "a clean run makes delegate/<date>-<slug>, commits, and prints the report, the stat, a clean tree and the exit" \
  "[ \$d_rc -eq 0 ] && case \"\$dbr\" in delegate/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-add-a-line) ;; *) false ;; esac && grep -qx 'tree: clean' <<<\"\$d_out\" && grep -qx 'exit status: 0' <<<\"\$d_out\" && grep -q 'worker-did.txt' <<<\"\$d_out\" && grep -q 'line-20' <<<\"\$d_out\" && grep -q 'line-06' <<<\"\$d_out\" && ! grep -q 'line-01' <<<\"\$d_out\" && grep -q \"commits on \$dbr\" <<<\"\$d_out\" && ! grep -q '^BREACH:' <<<\"\$d_out\" && [ -n \"\$dlog\" ] && grep -q 'line-01' \"\$dlog\" && [ -z \"\$(find \"\$dproj\" -name '*.log' -type f)\" ] && [ -z \"\$(git -C \"\$dproj\" status --porcelain)\" ] && ! grep -q '^cost:' <<<\"\$d_out\" && ! grep -q 'sandbox profile changed' <<<\"\$d_out\""
check "the worker's prompt is the preamble, then the task, and grok is called headless" \
  "grep -q 'Read AGENTS.md' \"\$dprompt\" && grep -q \"You are on branch \$dbr; stay on it.\" \"\$dprompt\" && grep -q 'just save' \"\$dprompt\" && grep -q 'just publish' \"\$dprompt\" && grep -q 'git push' \"\$dprompt\" && grep -q 'just ship' \"\$dprompt\" && grep -q 'just deploy' \"\$dprompt\" && grep -q 'server or GitHub' \"\$dprompt\" && grep -q 'merge, rebase, or delete a branch' \"\$dprompt\" && grep -q 'Never start a sub-agent or a parallel task' \"\$dprompt\" && grep -q 'at most 15 lines' \"\$dprompt\" && [ \"\$(tail -n 1 \"\$dprompt\")\" = 'add a line' ] && [ \"\$(cat \"\$dprompt.fmt\")\" = plain ] && [ -z \"\$(cat \"\$dprompt.model\")\" ] && [ \"\$(cat \"\$dprompt.perm\")\" = auto ] && grep -qx 'Bash(git push:\*)' \"\$dprompt.deny\" && grep -qx 'Bash(just ship:\*)' \"\$dprompt.deny\""
check "the preamble grok receives says never begin a command with a variable assignment" \
  "grep -Fq 'Never begin a command with a variable assignment; put multi-step logic in a recipe or a test file.' \"\$dprompt\""
check "grok's deny list also names the shell wrappers that step around rm" \
  "grep -qx 'Bash(sh:\*)' \"\$dprompt.deny\" && grep -qx 'Bash(bash:\*)' \"\$dprompt.deny\" && grep -qx 'Bash(zsh:\*)' \"\$dprompt.deny\" && grep -qx 'Bash(eval:\*)' \"\$dprompt.deny\" && grep -qx 'Bash(xargs:\*)' \"\$dprompt.deny\" && grep -qx 'Bash(env:\*)' \"\$dprompt.deny\""
check "grok is passed --disable-web-search, the flag grok --help names (n-5b9b58)" \
  "[ \"\$(cat \"\$dprompt.web\")\" = yes ] && grep -q -- '--disable-web-search' '$root/.ai-backbone/core.just'"
check "grok's argv denies the keystore commands, ssh-add and the secret paths, and the sandbox profile names the same paths" \
  "grep -qx 'Bash(security find-generic-password:\*)' \"\$dprompt.deny\" && grep -qx 'Bash(security find-internet-password:\*)' \"\$dprompt.deny\" && grep -qx 'Bash(/usr/bin/security find-generic-password:\*)' \"\$dprompt.deny\" && grep -qx 'Bash(/usr/bin/security find-internet-password:\*)' \"\$dprompt.deny\" && grep -qx 'Bash(secret-tool lookup:\*)' \"\$dprompt.deny\" && grep -qx 'Bash(/usr/bin/secret-tool lookup:\*)' \"\$dprompt.deny\" && grep -qx 'Bash(just with-secret:\*)' \"\$dprompt.deny\" && grep -qx 'Bash(ssh-add:\*)' \"\$dprompt.deny\" && grep -qx 'Bash(/usr/bin/ssh-add:\*)' \"\$dprompt.deny\" && grep -Fqx 'Bash(just delegate-accept:*)' \"\$dprompt.deny\" && grep -Fqx 'Bash(just delegate-drop:*)' \"\$dprompt.deny\" && grep -Fqx 'Read(**/.aws/**)' \"\$dprompt.deny\" && grep -Fqx 'Read(**/.ssh/**)' \"\$dprompt.deny\" && grep -Fqx 'Read(**/.env)' \"\$dprompt.deny\" && grep -Fqx 'Read(**/.envrc)' \"\$dprompt.deny\" && grep -Fqx 'Read(**/ssh-agent.sock)' \"\$dprompt.deny\" && grep -Fqx 'Read(**/brain/secrets/**)' \"\$dprompt.deny\" && grep -Fqx 'Write(**/.grok/sandbox.toml)' \"\$dprompt.deny\" && grep -Fqx 'Edit(**/.grok/sandbox.toml)' \"\$dprompt.deny\" && ! grep -q '.env.example' \"\$dprompt.deny\" && [ \"\$(cat \"\$dprompt.sandbox\")\" = ai-backbone-delegate ] && grep -q 'extends = \"workspace\"' \"\$dproj/.grok/sandbox.toml\" && grep -q '\"~/.ssh\"' \"\$dproj/.grok/sandbox.toml\" && grep -q '\"~/.aws\"' \"\$dproj/.grok/sandbox.toml\" && grep -Fq '\"**/.env\"' \"\$dproj/.grok/sandbox.toml\" && ! grep -q '/Users/' \"\$dproj/.grok/sandbox.toml\" && ! grep -qx '  \"~/.grok\",' \"\$dproj/.grok/sandbox.toml\" && ! grep -q 'grok/auth.json' \"\$dproj/.grok/sandbox.toml\" && ! [ -f \"\$dhome/.grok/sandbox.toml\" ]"
git -C "$dproj" checkout -q main
d_run ok grok "" delegate "add a line"
dbr2=$(git -C "$dproj" symbolic-ref --short HEAD)
check "the same task on the same day gets a short suffix, and the first branch stays" "[ \$d_rc -eq 0 ] && [ \"\$dbr2\" = \"\${dbr}-2\" ] && git -C \"\$dproj\" show-ref --verify --quiet \"refs/heads/\$dbr\" && git -C \"\$dproj\" show-ref --verify --quiet \"refs/heads/\$dbr2\""
buildx_grant_ok() {
  awk -v home="$1" '
    /^# BEGIN ai-backbone delegate/ { blocks++ }
    /^read_write = \[/ { mode = "rw"; next }
    /^deny = \[/ { mode = "deny"; next }
    /^\]/ { mode = ""; next }
    {
      if (index($0, home "/.docker/buildx")) {
        if (mode == "rw") rw++
        else bad++
      }
      if (index($0, "~/.docker/buildx")) tilde++
    }
    END { exit !(blocks == 1 && rw == 1 && bad == 0 && tilde == 0) }
  ' "$2"
}
check "the grok sandbox grants write on the home docker buildx directory (n-9e0540)" \
  "buildx_grant_ok \"\$dhome\" \"\$dproj/.grok/sandbox.toml\" && grep -q n-9e0540 \"\$root/.agents/skills/delegate/SKILL.md\" && grep -q 'docker/buildx' \"\$root/.agents/skills/delegate/SKILL.md\""
swift_grant_ok() {
  awk -v home="$1" '
    /^read_write = \[/ { mode = "rw"; next }
    /^deny = \[/ { mode = "deny"; next }
    /^\]/ { mode = ""; next }
    {
      if (index($0, home "/Library/Caches/org.swift.swiftpm")) {
        if (mode == "rw") spm++
        else bad++
      }
      if (index($0, home "/Library/Developer/Xcode/DerivedData")) {
        if (mode == "rw") dd++
        else bad++
      }
      if (index($0, "~/Library/Caches/org.swift.swiftpm")) tilde++
      if (index($0, "~/Library/Developer/Xcode/DerivedData")) tilde++
    }
    END { exit !(spm == 1 && dd == 1 && bad == 0 && tilde == 0) }
  ' "$2"
}
check "the grok sandbox grants write on the Swift package cache and DerivedData as full paths (n-3510d4)" \
  "swift_grant_ok \"\$dhome\" \"\$dproj/.grok/sandbox.toml\" && grep -qx 'restrict_network = true' \"\$dproj/.grok/sandbox.toml\" && grep -q n-3510d4 \"\$root/.agents/skills/delegate/SKILL.md\" && grep -q 'org.swift.swiftpm' \"\$root/.agents/skills/delegate/SKILL.md\""
check "the grok sandbox profile is the project file, not the shared home file" \
  "[ -f \"\$dproj/.grok/sandbox.toml\" ] && ! [ -f \"\$dhome/.grok/sandbox.toml\" ] && grep -Fq '[profiles.ai-backbone-delegate]' \"\$dproj/.grok/sandbox.toml\" && grep -q '.grok/sandbox.toml' \"\$dproj/.git/info/exclude\" && grep -q n-afbc90 \"\$root/.agents/skills/delegate/SKILL.md\""
d_new grokhome
mkdir -p "$dhome/.grok"
printf '%s\n' '# user leftover' '[profiles.ai-backbone-delegate]' 'extends = "workspace"' > "$dhome/.grok/sandbox.toml"
cp "$dhome/.grok/sandbox.toml" "$tmp/home-sandbox-before"
d_run ok grok "" delegate "add a line"
check "a leftover home sandbox.toml is not rewritten, and the run uses a project profile" \
  "cmp -s \"$tmp/home-sandbox-before\" \"\$dhome/.grok/sandbox.toml\" && [ \"\$(cat \"\$dprompt.sandbox\")\" = ai-backbone-delegate-job ] && grep -Fq '[profiles.ai-backbone-delegate-job]' \"\$dproj/.grok/sandbox.toml\" && grep -q '\"~/.ssh\"' \"\$dproj/.grok/sandbox.toml\""
check "grok has no per-run sandbox file, so the home profile is left alone (n-a6542a)" \
  "grep -q 'per-run profile file would not be read' '$root/.agents/skills/delegate/SKILL.md' && grep -q 'a profile name' '$root/.agents/skills/delegate/SKILL.md' && cmp -s \"$tmp/home-sandbox-before\" \"\$dhome/.grok/sandbox.toml\""
d_new fetchok
printf '%s\n' '[package]' 'name = "demo"' 'version = "0.1.0"' 'edition = "2021"' > "$dproj/Cargo.toml"
git -C "$dproj" add Cargo.toml
git -C "$dproj" commit -qm "chore: rust" --no-verify
cat > "$dbin/cargo" << 'CARGOEOF'
#!/bin/sh
printf '%s\n' "$*" > "$FAKE_WORKER_PROMPT.cargo"
if [ "${FAKE_CARGO_RC:-0}" -ne 0 ]; then
  printf '%s\n' "error: failed to download crate leftpad"
  exit 1
fi
exit 0
CARGOEOF
chmod +x "$dbin/cargo"
d_run ok grok "" delegate "add a line"
check "a Rust project is cargo fetch outside the sandbox before the worker, with no crates-io patch (n-c4e0f1)" \
  "[ \$d_rc -eq 0 ] && [ \"\$(cat \"\$dprompt.cargo\")\" = fetch ] && [ ! -e \"\$dproj/.cargo/config.toml\" ] && grep -q 'Never vendor a crate or patch crates-io' \"\$dprompt\" && grep -q 'stop and say which crate' \"\$dprompt\" && grep -q 'cargo fetch' '$root/.agents/skills/delegate/SKILL.md'"
rm -f "$dbin/cargo"
d_new fetchbad
printf '%s\n' '[package]' 'name = "demo"' 'version = "0.1.0"' 'edition = "2021"' > "$dproj/Cargo.toml"
git -C "$dproj" add Cargo.toml
git -C "$dproj" commit -qm "chore: rust" --no-verify
cat > "$dbin/cargo" << 'CARGOEOF'
#!/bin/sh
printf '%s\n' "error: failed to download crate leftpad" >&2
exit 1
CARGOEOF
chmod +x "$dbin/cargo"
d_run ok grok "" delegate "add a line"
check "a refused crate fetch stops before the worker and names the crate (n-c4e0f1)" \
  "[ \$d_rc -ne 0 ] && grep -q 'does not vendor or patch crates-io' <<<\"\$d_out\" && grep -q leftpad <<<\"\$d_out\" && [ ! -f \"\$dproj/worker-did.txt\" ] && [ -z \"\$(git -C \"\$dproj\" branch --list 'delegate/*')\" ] && [ ! -e \"\$dproj/.cargo/config.toml\" ]"
rm -f "$dbin/cargo"
d_new mcpok
mkdir -p "$dproj/.grok"
printf '%s\n' 'model = "keep"' > "$dproj/.grok/config.toml"
git -C "$dproj" add .grok/config.toml
git -C "$dproj" commit -qm "chore: grok config" --no-verify
export DELEGATE_MCP="context7 https://mcp.example.com/mcp"
d_run ok grok "" delegate "add a line"
unset DELEGATE_MCP
mcp_seen() {
  [ "$d_rc" -eq 0 ] || { echo "rc $d_rc"; return 1; }
  [ "$(cat "$dprompt.grok-trust")" = yes ] || { echo "trust $(cat "$dprompt.grok-trust" 2>&1)"; return 1; }
  grep -q '^\[mcp_servers.context7\]' "$dprompt.mcp" || { echo "no table"; cat "$dprompt.mcp"; return 1; }
  grep -Fq 'url = "https://mcp.example.com/mcp"' "$dprompt.mcp" || { echo "no url"; return 1; }
  grep -qx 'model = "keep"' "$dproj/.grok/config.toml" || { echo "config left:"; cat "$dproj/.grok/config.toml"; return 1; }
  grep -q mcp_servers "$dproj/.grok/config.toml" && { echo "block stayed"; return 1; }
  grep -q 'BEGIN ai-backbone delegate mcp' "$dproj/.grok/config.toml" && { echo "marker stayed"; return 1; }
  [ ! -e "$dhome/.grok/trusted_folders" ] && [ ! -e "$dhome/.grok/trusted_folders.toml" ] || { echo "trust was saved"; return 1; }
  grep -qx '.grok/' "$root/.gitignore" || { echo "gitignore"; return 1; }
  grep -q 'trusted for that run only' "$root/.agents/skills/delegate/SKILL.md" || { echo "skill"; return 1; }
}
check "one MCP server is trusted for that run only and then removed (n-a5924b)" mcp_seen
d_new mcpbad
export DELEGATE_MCP="onlyone"
d_run ok grok "" delegate "add a line"
unset DELEGATE_MCP
check "a bad DELEGATE_MCP is refused before a branch (n-a5924b)" \
  "[ \$d_rc -ne 0 ] && d_one && grep -qx 'refuses: DELEGATE_MCP is one name and one http(s) url' <<<\"\$d_out\" && [ ! -f \"\$dproj/worker-did.txt\" ] && [ -z \"\$(git -C \"\$dproj\" branch --list 'delegate/*')\" ] && [ ! -e \"\$dproj/.grok/config.toml\" ]"
d_new titled
d_run ok grok "" delegate "$(printf 'From the company desk\n\nTitle: pin the crates\n\nDo the pin.')"
dbr=$(git -C "$dproj" symbolic-ref --short HEAD)
check "a Title line names the branch, and the task's first words do not" "case \"\$dbr\" in delegate/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-pin-the-crates) ;; *) false ;; esac && [ -z \"\$(git -C \"\$dproj\" branch --list 'delegate/*from-the-company*')\" ] && grep -q 'Do the pin.' \"\$dprompt\""
d_new strip
zw=$(perl -CS -Mutf8 -e 'binmode STDOUT, ":utf8"; print "\x{200b}\x{202e}"')
d_run ok grok "" delegate "add a ${zw}line<!--hide-->"
dbr=$(git -C "$dproj" symbolic-ref --short HEAD)
check "zero-width, a bidi mark and an HTML comment never reach the worker or the branch name" "case \"\$dbr\" in delegate/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-add-a-line) ;; *) false ;; esac && ! grep -q hide \"\$dprompt\" && perl -CS -Mutf8 -ne 'exit 1 if /[\\x{200B}\\x{202E}]/' \"\$dprompt\""
d_new bgwait
d_out=$(env -u WORKER HOME="$dhome" PATH="$dbin:$PATH" FAKE_WORKER_MODE=ok FAKE_WORKER_PROMPT="$dprompt" \
  WORKER=grok DELEGATE_TIMEOUT=2 just -f "$root/Justfile" -d "$dproj" delegate "wait in the background" 2>&1) && d_rc=0 || d_rc=$?
check "grok's background tasks are allowed the job's timeout, and the preamble says to stay in the foreground" \
  "[ \$d_rc -eq 0 ] && [ \"\$(cat \"\$dprompt.bgwait\")\" = 120 ] && grep -q 'Run long commands in the foreground' \"\$dprompt\""
d_new sccacheiso
cat > "$dbin/sccache" << 'EOF'
#!/usr/bin/env bash
# Stands in for sccache --stop-server. Records the port the recipe asked it
# to stop. Does not start a server.
if [ -n "${FAKE_WORKER_PROMPT:-}" ]; then
  printf '%s\n' "$*" >> "$FAKE_WORKER_PROMPT.sccache-argv"
  printf '%s\n' "${SCCACHE_SERVER_PORT:-}" >> "$FAKE_WORKER_PROMPT.sccache-stopped-port"
  if [ -n "${SCCACHE_SERVER_UDS+x}" ]; then printf '%s\n' set >> "$FAKE_WORKER_PROMPT.sccache-stop-uds"
  else printf '%s\n' unset >> "$FAKE_WORKER_PROMPT.sccache-stop-uds"; fi
fi
exit 0
EOF
chmod +x "$dbin/sccache"
export RUSTC_WRAPPER=sccache SCCACHE_SERVER_PORT=4226 SCCACHE_SERVER_UDS="$tmp/machine-sccache.sock"
d_run ok grok "" delegate "add a line"
unset RUSTC_WRAPPER SCCACHE_SERVER_PORT SCCACHE_SERVER_UDS
rm -f "$dbin/sccache"
check "a delegate job drops the inherited sccache wrapper and stops its own server (n-301ae6)" \
  "port=\$(cat \"\$dprompt.sccache-port\"); stop=\$(cat \"\$dprompt.sccache-stopped-port\"); lines=\$(wc -l < \"\$dprompt.sccache-stopped-port\"); lines=\${lines// /}; [ \$d_rc -eq 0 ] && [ \"\$(cat \"\$dprompt.rustc-wrapper\")\" = unset ] && [ \"\$(cat \"\$dprompt.sccache-uds\")\" = unset ] && case \"\$port\" in ''|*[!0-9]*|4226) false ;; *) true ;; esac && [ \"\$lines\" = 1 ] && [ \"\$stop\" = \"\$port\" ] && grep -qx -- '--stop-server' \"\$dprompt.sccache-argv\" && [ \"\$(cat \"\$dprompt.sccache-stop-uds\")\" = unset ] && grep -q SCCACHE_SERVER_PORT \"\$root/.agents/skills/delegate/SKILL.md\" && grep -q n-301ae6 \"\$root/.agents/skills/delegate/SKILL.md\""
d_new model
d_run ok claude cheap delegate "use claude"
check "the claude adapter calls claude -p with WORKER_MODEL" "[ \$d_rc -eq 0 ] && grep -q 'Read AGENTS.md' \"\$dprompt\" && [ -z \"\$(cat \"\$dprompt.fmt\")\" ] && [ \"\$(cat \"\$dprompt.model\")\" = cheap ]"
check "the preamble claude receives says never begin a command with a variable assignment" \
  "grep -Fq 'Never begin a command with a variable assignment; put multi-step logic in a recipe or a test file.' \"\$dprompt\""
d_new running
env -u WORKER HOME="$dhome" PATH="$dbin:$PATH" FAKE_WORKER_PROMPT="$dprompt" FAKE_WORKER_MODE=slow FAKE_WORKER_GO="$dgo" \
  WORKER=grok just -f "$root/Justfile" -d "$dproj" delegate "wait here" > "$tmp/delegate-bg.out" 2>&1 &
dbg=$!
i=0
while [ "$i" -lt 50 ]; do
  [ -s "$dhome/.cache/ai-backbone/delegate/delegate-running/running/branch" ] && break
  i=$((i+1)); sleep 0.1
done
d_run ok grok "" delegate "second task"
dst=$(env -u WORKER HOME="$dhome" PATH="$dbin:$PATH" just -f "$root/Justfile" -d "$dproj" delegate-status 2>&1 || true)
# The job deletes its lock as it exits, so remember the file before letting it go.
if [ -s "$dhome/.cache/ai-backbone/delegate/delegate-running/running/branch" ]; then lock_seen=yes; else lock_seen=no; fi
touch "$dgo"
suite_wait "$dbg" 120
check "while a job runs, a second delegate is refused in one line and status names its branch" \
  "[ \"\$lock_seen\" = yes ] && [ \$d_rc -ne 0 ] && d_one && grep -q 'refuses: a job is already running on delegate/' <<<\"\$d_out\" && grep -q 'job: running on delegate/' <<<\"\$dst\""
d_new report
d_run ok grok "" delegate "add a line"
dst=$(env -u WORKER HOME="$dhome" PATH="$dbin:$PATH" just -f "$root/Justfile" -d "$dproj" delegate-status 2>&1 || true)
check "with no job running, status shows the last report and the open delegate branch" \
  "grep -qx 'job: none' <<<\"\$dst\" && grep -q 'line-20' <<<\"\$dst\" && ! grep -q 'line-01' <<<\"\$dst\" && grep -q 'delegate/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-add-a-line' <<<\"\$dst\" && ! grep -q '^last run:' <<<\"\$dst\""
d_new accept
d_run ok grok "" delegate "add a line"
d_run ok "" "" delegate-accept
check "accept fast-forwards the default branch and deletes the delegate branch" \
  "[ \$d_rc -eq 0 ] && grep -q '^accepted delegate/.* onto main$' <<<\"\$d_out\" && [ \"\$(git -C \"\$dproj\" symbolic-ref --short HEAD)\" = main ] && [ -f \"\$dproj/worker-did.txt\" ] && [ -z \"\$(git -C \"\$dproj\" branch --list 'delegate/*')\" ] && git -C \"\$dproj\" merge-base --is-ancestor HEAD HEAD"
d_new acceptleftover
d_run ok grok "" delegate "add a line"
d_run fix grok "" delegate "fix the line"
leftdir="$tmp/leftover-hooks"
rm -rf "$leftdir"
mkdir -p "$leftdir"
printf '%s\n' '#!/bin/sh' 'echo staged-by-hook > leftover.txt' 'git add leftover.txt' 'echo refuses: leftover hook >&2' 'exit 1' > "$leftdir/reference-transaction"
chmod +x "$leftdir/reference-transaction"
git -C "$dproj" config --local extensions.worktreeConfig true
git -C "$dproj" config --worktree core.hooksPath "$(winpath "$leftdir")"
d_run ok "" "" delegate-accept
check "accept of a multi-commit branch under leftover hooksPath leaves a clean tree" \
  "[ \$d_rc -eq 0 ] && grep -q '^accepted delegate/.* onto main$' <<<\"\$d_out\" && [ \"\$(git -C \"\$dproj\" symbolic-ref --short HEAD)\" = main ] && [ -z \"\$(git -C \"\$dproj\" status --porcelain)\" ] && [ ! -f \"\$dproj/leftover.txt\" ] && [ -z \"\$(git -C \"\$dproj\" branch --list 'delegate/*')\" ] && [ -f \"\$dproj/worker-did.txt\" ]"
d_new signoff
git -C "$dproj" config commit.gpgsign true
git -C "$dproj" config gpg.format ssh
git -C "$dproj" config user.signingkey "$dhome/missing-signing-key"
d_out=$(env -u WORKER -u WORKER_MODEL -u DELEGATE_TIMEOUT -u DELEGATE_IDLE -u WORKER_BIN -u DELEGATE_BASE -u DELEGATE_YES -u FAKE_WORKER_TARGET \
  -u WORKER_LADDER -u OPENCODE_CONFIG -u OPENCODE_CONFIG_PROJECT_DISABLE \
  -u DELEGATE_MODEL -u KIMI_CODE_HOME -u SSH_AUTH_SOCK \
  HOME="$dhome" PATH="$dbin:$PATH" \
  FAKE_WORKER_PROMPT="$dprompt" FAKE_WORKER_MODE=sign FAKE_WORKER_GO="$dgo" \
  WORKER=grok \
  just -f "$root/Justfile" -d "$dproj" delegate "sign it" 2>&1) && d_rc=0 || d_rc=$?
check "a worker whose signing key is unreadable still commits (n-afbc90)" \
  "[ \$d_rc -eq 0 ] && [ -f \"\$dproj/worker-signed.txt\" ] && [ -z \"\$(git -C \"\$dproj\" status --porcelain)\" ] && grep -q 'worker signed the task' <<<\"\$d_out\""
# A reachable agent socket used to install a key:: signing key. The socket
# file is not a live agent: signing through it fails, so the old path cannot
# commit. The worker turns signing off instead.
d_new signsock
git -C "$dproj" config commit.gpgsign true
git -C "$dproj" config gpg.format ssh
printf '%s\n' 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFakeKeyForDelegateTest nobody@test' > "$dhome/fake.pub"
git -C "$dproj" config user.signingkey "$dhome/fake.pub"
rm -f "$tmp/agent.sock"
python3 -c 'import socket,sys; s=socket.socket(socket.AF_UNIX); s.bind(sys.argv[1]); s.close()' "$tmp/agent.sock"
d_out=$(env -u WORKER -u WORKER_MODEL -u DELEGATE_TIMEOUT -u DELEGATE_IDLE -u WORKER_BIN -u DELEGATE_BASE -u DELEGATE_YES -u FAKE_WORKER_TARGET \
  -u WORKER_LADDER -u OPENCODE_CONFIG -u OPENCODE_CONFIG_PROJECT_DISABLE \
  -u DELEGATE_MODEL -u KIMI_CODE_HOME \
  HOME="$dhome" PATH="$dbin:$PATH" SSH_AUTH_SOCK="$tmp/agent.sock" \
  FAKE_WORKER_PROMPT="$dprompt" FAKE_WORKER_MODE=sign FAKE_WORKER_GO="$dgo" \
  WORKER=grok \
  just -f "$root/Justfile" -d "$dproj" delegate "sign it" 2>&1) && d_rc=0 || d_rc=$?
dbr=$(git -C "$dproj" symbolic-ref --short HEAD)
sock_mark=$(git -C "$dproj" config --get "branch.${dbr}.delegateUnsigned" 2>/dev/null || true)
sock_key=$(git -C "$dproj" config --worktree --get user.signingkey 2>/dev/null || true)
sock_gpg=$(git -C "$dproj" config --worktree --get commit.gpgsign 2>/dev/null || true)
sock_body=$(git -C "$dproj" cat-file -p HEAD)
sock_head=${sock_body%%$'\n\n'*}
case "$sock_head" in
  *gpgsig\ *) sock_signed=yes ;;
  *) sock_signed=no ;;
esac
check "a worker never signs, even when the agent socket and a key file are both there" \
  "[ \$d_rc -eq 0 ] && [ \"\$sock_mark\" = 1 ] && [ -z \"\$sock_key\" ] && [ -z \"\$sock_gpg\" ] && [ \"\$sock_signed\" = no ] && ! grep -q 'key::' <<<\"\$sock_key\" && grep -q 'worker signed the task' <<<\"\$d_out\""
cat > "$tmp/ok-sign" << 'EOF'
#!/bin/sh
buf=
for a in "$@"; do buf=$a; done
printf '%s\n' '-----BEGIN SSH SIGNATURE-----' 'ZmFrZQ==' '-----END SSH SIGNATURE-----' > "$buf.sig"
exit 0
EOF
chmod +x "$tmp/ok-sign"
printf '%s\n' '#!/bin/sh' "echo called >> '$tmp/fail-sign.calls'" 'exit 1' > "$tmp/fail-sign"
chmod +x "$tmp/fail-sign"
realgit=$(command -v git)
mkdir -p "$tmp/git-norebase" "$tmp/git-dirty"
cat > "$tmp/git-norebase/git" << EOF
#!/bin/sh
real="$realgit"
for a in "\$@"; do
  if [ "\$a" = rebase ]; then exit 0; fi
done
exec "\$real" "\$@"
EOF
cat > "$tmp/git-dirty/git" << EOF
#!/bin/sh
real="$realgit"
ff=0
prev=
for a in "\$@"; do
  if [ "\$prev" = merge ] && [ "\$a" = --ff-only ]; then ff=1; fi
  prev=\$a
done
if [ "\$ff" -eq 0 ]; then
  exec "\$real" "\$@"
fi
"\$real" "\$@"
rc=\$?
if [ "\$rc" -eq 0 ]; then
  wt=
  prev=
  for a in "\$@"; do
    if [ "\$prev" = -C ]; then wt=\$a; fi
    prev=\$a
  done
  if [ -z "\$wt" ]; then wt=\$(pwd); fi
  printf 'dirty-after-ff\n' >> "\$wt/README.md"
fi
exit \$rc
EOF
chmod +x "$tmp/git-norebase/git" "$tmp/git-dirty/git"
d_new signok
git -C "$dproj" config commit.gpgsign true
git -C "$dproj" config gpg.format ssh
git -C "$dproj" config user.signingkey "$dhome/fake.pub"
git -C "$dproj" config gpg.ssh.program "$tmp/ok-sign"
d_out=$(env -u WORKER -u WORKER_MODEL -u DELEGATE_TIMEOUT -u DELEGATE_IDLE -u WORKER_BIN -u DELEGATE_BASE -u DELEGATE_YES -u FAKE_WORKER_TARGET \
  -u WORKER_LADDER -u OPENCODE_CONFIG -u OPENCODE_CONFIG_PROJECT_DISABLE \
  -u DELEGATE_MODEL -u KIMI_CODE_HOME -u SSH_AUTH_SOCK \
  HOME="$dhome" PATH="$dbin:$PATH" \
  FAKE_WORKER_PROMPT="$dprompt" FAKE_WORKER_MODE=sign FAKE_WORKER_GO="$dgo" \
  WORKER=grok \
  just -f "$root/Justfile" -d "$dproj" delegate "sign it" 2>&1) && d_rc=0 || d_rc=$?
ok_br=$(git -C "$dproj" symbolic-ref --short HEAD)
d_run ok "" "" delegate-accept
ok_body=$(git -C "$dproj" cat-file -p HEAD)
ok_head=${ok_body%%$'\n\n'*}
case "$ok_head" in
  *gpgsig\ *) ok_signed=yes ;;
  *) ok_signed=no ;;
esac
ok_mark=$(git -C "$dproj" config --get "branch.${ok_br}.delegateUnsigned" 2>/dev/null || true)
check "accept signs the marked branch and clears the mark only after main moves" \
  "[ \$d_rc -eq 0 ] && [ \"\$ok_signed\" = yes ] && grep -q '^accepted delegate/.* onto main$' <<<\"\$d_out\" && [ -z \"\$(git -C \"\$dproj\" branch --list 'delegate/*')\" ] && [ -z \"\$ok_mark\" ] && [ \"\$(git -C \"\$dproj\" symbolic-ref --short HEAD)\" = main ]"
d_new signfail
git -C "$dproj" config commit.gpgsign true
git -C "$dproj" config gpg.format ssh
git -C "$dproj" config user.signingkey "$dhome/fake.pub"
git -C "$dproj" config gpg.ssh.program "$tmp/fail-sign"
rm -f "$tmp/fail-sign.calls"
d_out=$(env -u WORKER -u WORKER_MODEL -u DELEGATE_TIMEOUT -u DELEGATE_IDLE -u WORKER_BIN -u DELEGATE_BASE -u DELEGATE_YES -u FAKE_WORKER_TARGET \
  -u WORKER_LADDER -u OPENCODE_CONFIG -u OPENCODE_CONFIG_PROJECT_DISABLE \
  -u DELEGATE_MODEL -u KIMI_CODE_HOME -u SSH_AUTH_SOCK \
  HOME="$dhome" PATH="$dbin:$PATH" \
  FAKE_WORKER_PROMPT="$dprompt" FAKE_WORKER_MODE=sign FAKE_WORKER_GO="$dgo" \
  WORKER=grok \
  just -f "$root/Justfile" -d "$dproj" delegate "sign it" 2>&1) && d_rc=0 || d_rc=$?
fail_br=$(git -C "$dproj" symbolic-ref --short HEAD)
fail_main=$(git -C "$dproj" rev-parse refs/heads/main)
fail_tip=$(git -C "$dproj" rev-parse "refs/heads/$fail_br")
rm -f "$tmp/fail-sign.calls"
d_run ok "" "" delegate-accept
fail_mark=$(git -C "$dproj" config --get "branch.${fail_br}.delegateUnsigned" 2>/dev/null || true)
fail_main_after=$(git -C "$dproj" rev-parse refs/heads/main)
fail_tip_after=$(git -C "$dproj" rev-parse "refs/heads/$fail_br")
if [ -d "$dproj/.git/rebase-merge" ] || [ -d "$dproj/.git/rebase-apply" ]; then fail_rebase=yes; else fail_rebase=no; fi
if [ -s "$tmp/fail-sign.calls" ]; then fail_called=yes; else fail_called=no; fi
check "a signer that fails aborts the rebase, keeps the mark and the branch, and leaves main" \
  "[ \$d_rc -ne 0 ] && d_one && grep -qx 'refuses: could not sign' <<<\"\$d_out\" && [ \"\$fail_called\" = yes ] && [ \"\$fail_rebase\" = no ] && [ \"\$fail_mark\" = 1 ] && [ \"\$fail_main\" = \"\$fail_main_after\" ] && [ \"\$fail_tip\" = \"\$fail_tip_after\" ] && [ -z \"\$(git -C \"\$dproj\" status --porcelain)\" ] && [ \"\$(git -C \"\$dproj\" symbolic-ref --short HEAD)\" = \"\$fail_br\" ]"
d_new signbare
git -C "$dproj" config commit.gpgsign true
git -C "$dproj" config gpg.format ssh
git -C "$dproj" config user.signingkey "$dhome/fake.pub"
git -C "$dproj" config gpg.ssh.program "$tmp/fail-sign"
d_out=$(env -u WORKER -u WORKER_MODEL -u DELEGATE_TIMEOUT -u DELEGATE_IDLE -u WORKER_BIN -u DELEGATE_BASE -u DELEGATE_YES -u FAKE_WORKER_TARGET \
  -u WORKER_LADDER -u OPENCODE_CONFIG -u OPENCODE_CONFIG_PROJECT_DISABLE \
  -u DELEGATE_MODEL -u KIMI_CODE_HOME -u SSH_AUTH_SOCK \
  HOME="$dhome" PATH="$dbin:$PATH" \
  FAKE_WORKER_PROMPT="$dprompt" FAKE_WORKER_MODE=sign FAKE_WORKER_GO="$dgo" \
  WORKER=grok \
  just -f "$root/Justfile" -d "$dproj" delegate "sign it" 2>&1) && d_rc=0 || d_rc=$?
bare_br=$(git -C "$dproj" symbolic-ref --short HEAD)
bare_main=$(git -C "$dproj" rev-parse refs/heads/main)
bare_tip=$(git -C "$dproj" rev-parse "refs/heads/$bare_br")
rm -f "$tmp/fail-sign.calls"
d_out=$(env -u WORKER -u SSH_AUTH_SOCK HOME="$dhome" PATH="$tmp/git-norebase:$dbin:$PATH" \
  just -f "$root/Justfile" -d "$dproj" delegate-accept 2>&1) && d_rc=0 || d_rc=$?
bare_mark=$(git -C "$dproj" config --get "branch.${bare_br}.delegateUnsigned" 2>/dev/null || true)
bare_main_after=$(git -C "$dproj" rev-parse refs/heads/main)
bare_tip_after=$(git -C "$dproj" rev-parse "refs/heads/$bare_br")
if [ -s "$tmp/fail-sign.calls" ]; then bare_called=yes; else bare_called=no; fi
check "accept refuses when rebase reports success but a commit has no signature" \
  "[ \$d_rc -ne 0 ] && grep -qx 'refuses: could not sign' <<<\"\$d_out\" && [ \"\$bare_called\" = no ] && [ \"\$bare_mark\" = 1 ] && [ \"\$bare_main\" = \"\$bare_main_after\" ] && [ \"\$bare_tip\" = \"\$bare_tip_after\" ] && git -C \"\$dproj\" show-ref --verify --quiet \"refs/heads/\$bare_br\""
d_new dirtyff
d_run ok grok "" delegate "add a line"
d_out=$(env -u WORKER HOME="$dhome" PATH="$tmp/git-dirty:$dbin:$PATH" \
  just -f "$root/Justfile" -d "$dproj" delegate-accept 2>&1) && d_rc=0 || d_rc=$?
check "a dirty tree after the fast-forward is printed and left" \
  "[ \$d_rc -ne 0 ] && grep -qx 'refuses: the tree is dirty after the fast-forward' <<<\"\$d_out\" && grep -q 'README.md' <<<\"\$d_out\" && grep -qx 'dirty-after-ff' \"\$dproj/README.md\""
d_new dirtythere
d_run ok grok "" delegate "add a line"
git -C "$dproj" checkout -q main
d_out=$(env -u WORKER HOME="$dhome" PATH="$tmp/git-dirty:$dbin:$PATH" \
  just -f "$root/Justfile" -d "$dproj" delegate-accept 2>&1) && d_rc=0 || d_rc=$?
check "a dirty tree in the base worktree after the fast-forward is printed and left" \
  "[ \$d_rc -ne 0 ] && grep -qx 'refuses: the tree is dirty after the fast-forward' <<<\"\$d_out\" && grep -q 'README.md' <<<\"\$d_out\" && grep -qx 'dirty-after-ff' \"\$dproj/README.md\""
d_new acceptrun
d_run ok grok "" delegate "add a line"
run_br=$(git -C "$dproj" symbolic-ref --short HEAD)
run_main=$(git -C "$dproj" rev-parse refs/heads/main)
run_hooks="$dhome/.cache/ai-backbone/delegate/$(basename "$dproj")/live.hooks"
mkdir -p "$run_hooks"
printf '%s\n' '#!/bin/sh' 'exit 0' > "$run_hooks/reference-transaction"
chmod +x "$run_hooks/reference-transaction"
git -C "$dproj" config --local extensions.worktreeConfig true
git -C "$dproj" config --worktree core.hooksPath "$(winpath "$run_hooks")"
run_lock="$dhome/.cache/ai-backbone/delegate/$(basename "$dproj")/running"
mkdir -p "$run_lock"
python3 -c 'import time; time.sleep(180)' &
run_live=$!
printf '%s\n' "$run_live" > "$run_lock/pid"
d_run ok "" "" delegate-accept
run_hooks_after=$(git -C "$dproj" config --worktree --get core.hooksPath 2>/dev/null || true)
run_main_after=$(git -C "$dproj" rev-parse refs/heads/main)
if git -C "$dproj" show-ref --verify --quiet "refs/heads/$run_br"; then run_still=yes; else run_still=no; fi
suite_stop "$run_live"
rm -rf "$run_lock"
check "accept refuses while a job is running, and does not skip that job's hook" \
  "[ \$d_rc -ne 0 ] && d_one && grep -qx 'refuses: a job is running' <<<\"\$d_out\" && [ \"\$run_still\" = yes ] && [ \"\$run_main\" = \"\$run_main_after\" ] && samepath \"\$run_hooks_after\" \"\$run_hooks\" && [ -f \"\$run_hooks/reference-transaction\" ]"
d_new sandedit
d_run sandboxedit grok "" delegate "touch the profile"
check "a worker that rewrites the project sandbox profile is named when the job ends" \
  "[ \$d_rc -eq 0 ] && grep -qx 'sandbox profile changed: .grok/sandbox.toml' <<<\"\$d_out\" && grep -q 'worker changed the profile' \"\$dproj/.grok/sandbox.toml\""
d_new noff
d_run ok grok "" delegate "add a line"
nbr=$(git -C "$dproj" symbolic-ref --short HEAD)
git -C "$dproj" checkout -q main
printf 'more\n' >> "$dproj/README.md"
git -C "$dproj" add README.md
git -C "$dproj" commit -qm "chore: main moved"
d_run ok "" "" delegate-accept
check "accept refuses when the delegate branch is not a fast-forward, and keeps it" \
  "[ \$d_rc -ne 0 ] && grep -qx \"refuses: \$nbr is not a fast-forward of main\" <<<\"\$d_out\" && git -C \"\$dproj\" show-ref --verify --quiet \"refs/heads/\$nbr\""
d_new drop
d_run ok grok "" delegate "add a line"
nbr=$(git -C "$dproj" symbolic-ref --short HEAD)
d_out=$(printf 'n\n' | env -u WORKER HOME="$dhome" just -f "$root/Justfile" -d "$dproj" delegate-drop 2>&1) && d_rc=0 || d_rc=$?
kept=$d_rc
kept_msg=$d_out
if git -C "$dproj" show-ref --verify --quiet "refs/heads/$nbr"; then kept_branch=yes; else kept_branch=no; fi
d_out2=$(printf 'y\n' | env -u WORKER HOME="$dhome" just -f "$root/Justfile" -d "$dproj" delegate-drop 2>&1) && d_rc=0 || d_rc=$?
check "drop asks once: no keeps the branch, yes deletes it" \
  "[ \$kept -ne 0 ] && grep -q \"kept \$nbr\" <<<\"\$kept_msg\" && [ \"\$kept_branch\" = yes ] && [ \$d_rc -eq 0 ] && grep -q \"^dropped \$nbr\$\" <<<\"\$d_out2\" && [ -z \"\$(git -C \"\$dproj\" branch --list 'delegate/*')\" ] && [ \"\$(git -C \"\$dproj\" symbolic-ref --short HEAD)\" = main ]"
d_new two
d_run ok grok "" delegate "one thing"
git -C "$dproj" checkout -q main
d_run ok grok "" delegate "two things"
d_run ok "" "" delegate-drop
check "drop with two delegate branches asks for the name and deletes none" \
  "[ \$d_rc -ne 0 ] && grep -q 'refuses: name the branch' <<<\"\$d_out\" && [ \"\$(git -C \"\$dproj\" branch --list 'delegate/*' | wc -l | tr -d ' ')\" = 2 ]"
d_new fail
d_run fail grok "" delegate "break it"
check "the worker's exit status is the recipe's, and a dirty tree is said" \
  "[ \$d_rc -eq 3 ] && grep -qx 'exit status: 3' <<<\"\$d_out\""
hook_after=$(git -C "$dproj" config --worktree --get core.hooksPath 2>/dev/null || true)
check "a delegate whose worker fails leaves no job hooksPath (n-70dcaf)" "[ -z \"\$hook_after\" ]"
d_new dirt
d_run dirty grok "" delegate "leave a file"
check "a worker that leaves a file is reported as a dirty tree" "grep -qx 'tree: dirty' <<<\"\$d_out\" && [ -f \"\$dproj/left-dirty.txt\" ]"
d_new badt
d_out=$(env -u WORKER HOME="$dhome" PATH="$dbin:$PATH" FAKE_WORKER_MODE=ok WORKER=grok DELEGATE_TIMEOUT=no \
  just -f "$root/Justfile" -d "$dproj" delegate "add a line" 2>&1) && d_rc=0 || d_rc=$?
d_out0=$(env -u WORKER HOME="$dhome" PATH="$dbin:$PATH" FAKE_WORKER_MODE=ok WORKER=grok DELEGATE_TIMEOUT=0 \
  just -f "$root/Justfile" -d "$dproj" delegate "add a line" 2>&1) && d_rc0=0 || d_rc0=$?
check "a DELEGATE_TIMEOUT that is not a positive number of minutes is refused in one line" \
  "[ \$d_rc -ne 0 ] && d_one && grep -qx 'refuses: DELEGATE_TIMEOUT must be a positive number of minutes' <<<\"\$d_out\" && [ \$d_rc0 -ne 0 ] && grep -qx 'refuses: DELEGATE_TIMEOUT must be a positive number of minutes' <<<\"\$d_out0\" && [ -z \"\$(git -C \"\$dproj\" branch --list 'delegate/*')\" ]"
dh=$(just --list -f "$root/Justfile" | sed -n 's/^    delegate task.*# //p')
check "just delegate's help says DELEGATE_TIMEOUT is minutes (n-28ad13)" \
  "grep -qx 'DELEGATE_TIMEOUT is minutes for one job (180 if unset).' <<<\"\$dh\""
check "the delegate docs say DELEGATE_TIMEOUT is minutes, and a chain script's failure word matches its watcher (n-28ad13)" \
  "grep -q 'DELEGATE_TIMEOUT\` is minutes' '$root/.agents/skills/delegate/SKILL.md' && grep -q 'DELEGATE_TIMEOUT\` (minutes)' '$root/.agents/skills/delegate/SKILL.md' && grep -q 'how many minutes one job may run' '$root/docs/01-getting-started.md' && grep -q 'which is minutes' '$root/docs/specs/034-delegate.md' && grep -q 'default 180 minutes' '$root/docs/specs/034-delegate.md' && grep -q 'watcher that looks for DESK FAIL' '$root/.agents/skills/delegate/SKILL.md'"
d_new tout
t0=$SECONDS
d_out=$(env -u WORKER HOME="$dhome" PATH="$dbin:$PATH" FAKE_WORKER_MODE=timeout FAKE_WORKER_PROMPT="$dprompt" FAKE_WORKER_GO="$dgo" \
  WORKER=grok DELEGATE_TIMEOUT=0.05 just -f "$root/Justfile" -d "$dproj" delegate "sleep it" 2>&1) && d_rc=0 || d_rc=$?
elapsed=$((SECONDS - t0))
check "the run stops when DELEGATE_TIMEOUT passes and says timeout, before the worker finishes" \
  "[ \$d_rc -eq 124 ] && [ \$elapsed -lt 15 ] && grep -qx 'exit status: timeout' <<<\"\$d_out\" && grep -q '^report$' <<<\"\$d_out\" && ! grep -q finished <<<\"\$d_out\" && ! grep -q Terminated <<<\"\$d_out\""
hook_after=$(git -C "$dproj" config --worktree --get core.hooksPath 2>/dev/null || true)
check "a timed-out delegate leaves no job hooksPath (n-70dcaf)" "[ -z \"\$hook_after\" ]"
d_new hookprev
mkdir -p "$tmp/prev-hooks"
printf '%s\n' '#!/bin/sh' 'exit 0' > "$tmp/prev-hooks/pre-commit"
chmod +x "$tmp/prev-hooks/pre-commit"
git -C "$dproj" config --local extensions.worktreeConfig true
git -C "$dproj" config --worktree core.hooksPath "$(winpath "$tmp/prev-hooks")"
d_run ok grok "" delegate "add a line"
hook_after=$(git -C "$dproj" config --worktree --get core.hooksPath 2>/dev/null || true)
check "a finished delegate puts the previous hooks path back (n-70dcaf)" \
  "[ \$d_rc -eq 0 ] && samepath \"\$hook_after\" '$tmp/prev-hooks'"
d_new hooksig
git -C "$dproj" config --local extensions.worktreeConfig true
git -C "$dproj" config --worktree core.hooksPath "$(winpath "$tmp/prev-hooks")"
rm -f "$dgo"
env -u WORKER -u WORKER_MODEL -u DELEGATE_TIMEOUT -u DELEGATE_IDLE -u WORKER_BIN -u DELEGATE_BASE -u DELEGATE_YES \
  HOME="$dhome" PATH="$dbin:$PATH" FAKE_WORKER_PROMPT="$dprompt" FAKE_WORKER_MODE=slow FAKE_WORKER_GO="$dgo" \
  WORKER=grok just -f "$root/Justfile" -d "$dproj" delegate "wait here" >"$tmp/hooksig.out" 2>&1 &
hooksig=$!
hook_lock="$dhome/.cache/ai-backbone/delegate/$(basename "$dproj")/running/pid"
i=0
saw_job_hooks=""
while [ "$i" -lt 80 ]; do
  cur=$(git -C "$dproj" config --worktree --get core.hooksPath 2>/dev/null || true)
  case "$cur" in *.hooks) saw_job_hooks=$cur; break ;; esac
  i=$((i+1)); sleep 0.1
done
if [ -s "$hook_lock" ]; then kill -TERM "$(cat "$hook_lock")" 2>/dev/null || true; fi
suite_wait "$hooksig" 60
hook_after=$(git -C "$dproj" config --worktree --get core.hooksPath 2>/dev/null || true)
check "a delegate stopped by a signal puts the previous hooks path back (n-70dcaf)" \
  "[ -n \"\$saw_job_hooks\" ] && ! samepath \"\$saw_job_hooks\" '$tmp/prev-hooks' && samepath \"\$hook_after\" '$tmp/prev-hooks'"
# Git Bash on Windows has no process groups in ps (measured on windows-latest,
# 2026-10-22), so the idle stop never fires there and the job ends at the timeout.
if ps -A -o pid=,pgid= 2>/dev/null | awk 'NF == 2 { ok = 1 } END { exit !ok }'; then
  d_new idle
  t0=$SECONDS
  d_out=$(env -u WORKER HOME="$dhome" PATH="$dbin:$PATH" FAKE_WORKER_MODE=idle FAKE_WORKER_PROMPT="$dprompt" \
    WORKER=grok DELEGATE_TIMEOUT=5 DELEGATE_IDLE=0.05 just -f "$root/Justfile" -d "$dproj" delegate "idle after" 2>&1) && d_rc=0 || d_rc=$?
  elapsed=$((SECONDS - t0))
  check "a worker quiet after its commit, with nothing running, is stopped as finished (DELEGATE_IDLE)" \
    "[ \$d_rc -eq 0 ] && [ \$elapsed -lt 40 ] && grep -q 'went quiet after its last commit' <<<\"\$d_out\" && grep -qx 'exit status: 0' <<<\"\$d_out\" && grep -q 'worker did the task' <<<\"\$d_out\""
  git -C "$dproj" checkout -q main
  d_new idledirty
  t0=$SECONDS
  d_out=$(env -u WORKER HOME="$dhome" PATH="$dbin:$PATH" FAKE_WORKER_MODE=idledirty FAKE_WORKER_PROMPT="$dprompt" \
    WORKER=grok DELEGATE_TIMEOUT=5 DELEGATE_IDLE=0.05 just -f "$root/Justfile" -d "$dproj" delegate "idle dirty" 2>&1) && d_rc=0 || d_rc=$?
  elapsed=$((SECONDS - t0))
  check "a dirty tree is not ended by DELEGATE_IDLE" \
    "[ \$d_rc -eq 0 ] && [ \$elapsed -ge 15 ] && ! grep -q 'went quiet' <<<\"\$d_out\" && grep -qx 'exit status: 0' <<<\"\$d_out\" && [ -f \"\$dproj/left-dirty.txt\" ]"
  git -C "$dproj" checkout -q main
  d_new idlewindow
  t0=$SECONDS
  d_out=$(env -u WORKER HOME="$dhome" PATH="$dbin:$PATH" FAKE_WORKER_MODE=idlewindow FAKE_WORKER_PROMPT="$dprompt" \
    WORKER=grok DELEGATE_TIMEOUT=2 DELEGATE_IDLE=0.25 just -f "$root/Justfile" -d "$dproj" delegate "idle window" 2>&1) && d_rc=0 || d_rc=$?
  elapsed=$((SECONDS - t0))
  check "the idle end waits until the tree has been clean for the whole window" \
    "[ \$d_rc -eq 0 ] && [ \$elapsed -ge 18 ] && [ \$elapsed -lt 50 ] && grep -q 'went quiet after its last commit' <<<\"\$d_out\" && grep -qx 'exit status: 0' <<<\"\$d_out\" && [ ! -f \"\$dproj/left-dirty.txt\" ]"
  git -C "$dproj" checkout -q main
fi
d_new quiet
t0=$SECONDS
d_out=$(env -u WORKER HOME="$dhome" PATH="$dbin:$PATH" FAKE_WORKER_MODE=quiet FAKE_WORKER_PROMPT="$dprompt" \
  WORKER=grok DELEGATE_TIMEOUT=1 DELEGATE_IDLE=0.05 just -f "$root/Justfile" -d "$dproj" delegate "quiet no commit" 2>&1) && d_rc=0 || d_rc=$?
elapsed=$((SECONDS - t0))
check "a quiet worker with no new commit is not stopped by DELEGATE_IDLE" \
  "[ \$d_rc -eq 0 ] && [ \$elapsed -ge 10 ] && ! grep -q 'went quiet' <<<\"\$d_out\" && grep -qx 'exit status: 0' <<<\"\$d_out\""
git -C "$dproj" checkout -q main
d_out=$(env -u WORKER HOME="$dhome" PATH="$dbin:$PATH" FAKE_WORKER_MODE=ok WORKER=grok DELEGATE_IDLE=soon \
  just -f "$root/Justfile" -d "$dproj" delegate "bad idle" 2>&1) && d_rc=0 || d_rc=$?
check "DELEGATE_IDLE that is not a number is refused before any branch" \
  "[ \$d_rc -ne 0 ] && grep -qx 'refuses: DELEGATE_IDLE must be a number of minutes (0 turns it off)' <<<\"\$d_out\" && ! git -C \"\$dproj\" show-ref --verify --quiet refs/heads/delegate/\$(date +%Y-%m-%d)-bad-idle"
# The session that runs the recipe keeps its own input open (a harness, an
# agent's shell). A worker that waits for the end of that input never exits,
# and the job lasted until DELEGATE_TIMEOUT though the report was written.
# The open input is a fifo this shell holds, and the sleeper is stopped after
# the run. On bash 3.2.57, putting `<(sleep 30)` inside the command
# substitution made that substitution wait out the sleep after the worker had
# already exited 0 with its stdin on /dev/null (measured).
d_new stdin
sessin="$tmp/session-stdin"
rm -f "$sessin"
mkfifo "$sessin"
sleep 30 >"$sessin" &
sessin_pid=$!
t0=$SECONDS
d_out=$(env -u WORKER HOME="$dhome" PATH="$dbin:$PATH" FAKE_WORKER_MODE=stdin FAKE_WORKER_PROMPT="$dprompt" \
  WORKER=grok DELEGATE_TIMEOUT=0.25 just -f "$root/Justfile" -d "$dproj" delegate "read nothing" 2>&1 <"$sessin") && d_rc=0 || d_rc=$?
elapsed=$((SECONDS - t0))
suite_stop "$sessin_pid"
check "a worker never waits on the session's open input: the job ends when the worker does" \
  "[ \$d_rc -eq 0 ] && [ \$elapsed -lt 10 ] && grep -qx 'exit status: 0' <<<\"\$d_out\" && grep -q '^report$' <<<\"\$d_out\""
d_new push
bare="$tmp/delegate-bare-push"
git init -q --bare "$bare"
git -C "$dproj" remote add origin "$bare"
git -C "$dproj" push -q origin main
d_run push grok "" delegate "push it"
first=${d_out%%$'\n'*}
check "a worker that pushes is a breach, said first, and the recipe exits non-zero" \
  "[ \$d_rc -ne 0 ] && [ \"\$first\" = 'BREACH: remote refs changed' ] && grep -q '^report$' <<<\"\$d_out\" && ! grep -q 'default branch' <<<\"\$d_out\" && ! grep -q 'branch list changed' <<<\"\$d_out\""
d_new fetch
bare="$tmp/delegate-bare-fetch"
git init -q --bare "$bare"
git -C "$dproj" remote add origin "$bare"
git -C "$dproj" push -q origin main
d_run fetch grok "" delegate "fetch main"
check "a fetch that moves origin/main during the job is not a breach" \
  "[ \$d_rc -eq 0 ] && ! grep -q '^BREACH:' <<<\"\$d_out\" && [ \"\$(git -C \"\$dproj\" rev-parse refs/heads/main)\" != \"\$(git -C \"\$dproj\" rev-parse refs/remotes/origin/main)\" ]"
d_new third
bare="$tmp/delegate-bare-third"
git init -q --bare "$bare"
git -C "$dproj" remote add origin "$bare"
git -C "$dproj" push -q origin main
d_run third grok "" delegate "someone else pushes"
check "a third party pushing an unrelated commit is not a breach" \
  "[ \$d_rc -eq 0 ] && ! grep -q '^BREACH:' <<<\"\$d_out\" && git -C \"\$bare\" show-ref --verify --quiet refs/heads/unrelated && ! git -C \"\$dproj\" show-ref --verify --quiet refs/remotes/origin/unrelated"
d_new move
d_run move grok "" delegate "move main"
first=${d_out%%$'\n'*}
check "a worker that moves the default branch is a breach, said first" \
  "[ \$d_rc -ne 0 ] && [ \"\$first\" = 'BREACH: default branch main moved' ] && grep -q '^report$' <<<\"\$d_out\" && ! grep -q 'remote refs' <<<\"\$d_out\" && ! grep -q 'branch list changed' <<<\"\$d_out\""
d_new side
d_run branch grok "" delegate "add a branch"
first=${d_out%%$'\n'*}
check "a worker that adds a branch is a breach, said first" \
  "[ \$d_rc -ne 0 ] && [ \"\$first\" = 'BREACH: branch list changed' ] && grep -q '^report$' <<<\"\$d_out\" && git -C \"\$dproj\" show-ref --verify --quiet refs/heads/from-the-worker"
d_new othersess
d_run othersess grok "" delegate "other session"
check "a delegate branch another session creates during the run is not a breach" \
  "[ \$d_rc -eq 0 ] && ! grep -q '^BREACH:' <<<\"\$d_out\" && git -C \"\$dproj\" show-ref --verify --quiet refs/heads/delegate/other-session"
d_new nomerge
d_run merge grok "" delegate "do not merge"
dlog=""
for f in "$dhome/.cache/ai-backbone/delegate/delegate-nomerge"/*.log; do
  [ -f "$f" ] || continue
  dlog=$f
done
parents=$(git -C "$dproj" rev-list --parents -n 1 HEAD | wc -w | tr -d ' ')
check "a merge into the worker branch is refused at the ref, and the tip stays one parent" \
  "[ \$d_rc -eq 0 ] && [ \"\$parents\" = 2 ] && [ -n \"\$dlog\" ] && grep -q 'refuses: a merge is not a commit on this branch' \"\$dlog\" && ! grep -q '^BREACH:' <<<\"\$d_out\""
# A parallel lane is another worktree of the same repository. Its branch is
# checked out there, before or after this run, so it is not this run's change
# (n-1cbec4). Two worktrees, one created and one dropped during the job.
d_new siblingadd
side="$tmp/delegate-sibling-add"
rm -rf "$side"
d_out=$(env -u WORKER HOME="$dhome" PATH="$dbin:$PATH" FAKE_WORKER_MODE=sibling FAKE_WORKER_PROMPT="$dprompt" FAKE_WORKER_SIDE="$side" \
  WORKER=grok just -f "$root/Justfile" -d "$dproj" delegate "run beside a lane" 2>&1) && d_rc=0 || d_rc=$?
check "a lane branch another worktree creates during the run is not a breach" \
  "[ \$d_rc -eq 0 ] && ! grep -q '^BREACH:' <<<\"\$d_out\" && git -C \"\$dproj\" show-ref --verify --quiet refs/heads/lane/parallel && [ -f \"\$side/README.md\" ]"
git -C "$dproj" worktree remove --force "$side" 2>/dev/null || true
git -C "$dproj" branch -D lane/parallel >/dev/null 2>&1 || true
d_new siblingdrop
side="$tmp/delegate-sibling-drop"
rm -rf "$side"
git -C "$dproj" worktree add -q -b lane/old "$side"
d_out=$(env -u WORKER HOME="$dhome" PATH="$dbin:$PATH" FAKE_WORKER_MODE=siblingdrop FAKE_WORKER_PROMPT="$dprompt" FAKE_WORKER_SIDE="$side" \
  WORKER=grok just -f "$root/Justfile" -d "$dproj" delegate "run beside a lane that leaves" 2>&1) && d_rc=0 || d_rc=$?
check "a lane branch another worktree drops during the run is not a breach" \
  "[ \$d_rc -eq 0 ] && ! grep -q '^BREACH:' <<<\"\$d_out\" && ! git -C \"\$dproj\" show-ref --verify --quiet refs/heads/lane/old"
# n-154b76: two worktrees. The job's hooksPath must not be the one the sibling
# reads, and a merge in the sibling must succeed while the job is running.
d_new hookwt
side="$tmp/delegate-hookwt-side"
rm -rf "$side"
git -C "$dproj" worktree add -q -b lane/side "$side" main
mkdir -p "$tmp/real-hooks"
printf '#!/bin/sh\nexit 0\n' > "$tmp/real-hooks/pre-commit"
chmod +x "$tmp/real-hooks/pre-commit"
git -C "$dproj" config --local core.hooksPath "$(winpath "$tmp/real-hooks")"
d_out=$(env -u WORKER HOME="$dhome" PATH="$dbin:$PATH" FAKE_WORKER_MODE=hookwt FAKE_WORKER_PROMPT="$dprompt" FAKE_WORKER_SIDE="$side" \
  WORKER=grok just -f "$root/Justfile" -d "$dproj" delegate "merge beside a lane" 2>&1) && d_rc=0 || d_rc=$?
dlog=""
for f in "$dhome/.cache/ai-backbone/delegate/delegate-hookwt"/*.log; do
  [ -f "$f" ] || continue
  dlog=$f
done
hereh=$(cat "$dprompt.here-hooks" 2>/dev/null || true)
sideh=$(cat "$dprompt.side-hooks" 2>/dev/null || true)
localh=$(git -C "$dproj" config --local --get core.hooksPath 2>/dev/null || true)
workh=$(git -C "$dproj" config --worktree --get core.hooksPath 2>/dev/null || true)
ext=$(git -C "$dproj" config --local --get extensions.worktreeConfig 2>/dev/null || true)
sideparents=$(git -C "$dproj" rev-list --parents -n 1 lane/side | wc -w | tr -d ' ')
check "a running job's hooksPath locks only its worktree, and the sibling can merge" \
  "[ \$d_rc -eq 0 ] && ! grep -q '^BREACH:' <<<\"\$d_out\" && [ -n \"\$dlog\" ] && grep -q 'refuses: a merge is not a commit on this branch' \"\$dlog\" && [ \"\$(cat \"\$dprompt.side-merge\")\" = side-merge-ok ] && [ \"\$(cat \"\$dprompt.worker-merge\")\" = worker-merge-fail ] && samepath \"\$sideh\" \"\$tmp/real-hooks\" && ! samepath \"\$hereh\" \"\$tmp/real-hooks\" && case \"\$hereh\" in *.hooks*) true ;; *) false ;; esac && samepath \"\$localh\" \"\$tmp/real-hooks\" && [ -z \"\$workh\" ] && [ \"\$ext\" = true ] && [ \"\$sideparents\" -gt 2 ]"
git -C "$dproj" worktree remove --force "$side" 2>/dev/null || true
git -C "$dproj" branch -D lane/side >/dev/null 2>&1 || true
d_new laneown
d_run laneown grok "" delegate "make a lane"
first=${d_out%%$'\n'*}
check "a lane branch the worker creates and leaves unchecked is a breach" \
  "[ \$d_rc -ne 0 ] && [ \"\$first\" = 'BREACH: branch list changed' ] && git -C \"\$dproj\" show-ref --verify --quiet refs/heads/lane/sneak"
d_new fixround
d_run ok grok "" delegate "add a line"
dbr=$(git -C "$dproj" symbolic-ref --short HEAD)
d_run fix grok "" delegate "fix the line"
dcount=$(git -C "$dproj" branch --list 'delegate/*' | wc -l | tr -d ' ')
dahead=$(git -C "$dproj" rev-list --count main..HEAD)
check "a fix on a delegate branch stays there and keeps the first round's commit" \
  "[ \$d_rc -eq 0 ] && [ \"\$(git -C \"\$dproj\" symbolic-ref --short HEAD)\" = \"\$dbr\" ] && [ \"\$dcount\" = 1 ] && [ \"\$dahead\" = 2 ] && ! grep -q '^BREACH:' <<<\"\$d_out\" && grep -qx 'tree: clean' <<<\"\$d_out\" && grep -q 'worker fixed the task' <<<\"\$d_out\" && grep -q 'worker did the task' <<<\"\$d_out\" && [ -z \"\$(git -C \"\$dproj\" branch --list 'delegate/*fix-the-line')\" ]"
d_new fixdirty
d_run ok grok "" delegate "add a line"
printf 'x\n' >> "$dproj/README.md"
d_run fix grok "" delegate "fix the line"
check "a dirty delegate branch is refused before a second branch" \
  "[ \$d_rc -ne 0 ] && d_one && grep -qx 'refuses: the working tree is not clean' <<<\"\$d_out\" && [ \"\$(git -C \"\$dproj\" branch --list 'delegate/*' | wc -l | tr -d ' ')\" = 1 ]"
d_new fixmove
d_run ok grok "" delegate "add a line"
d_run move grok "" delegate "move main"
first=${d_out%%$'\n'*}
check "a fix round that moves the default branch is still a breach" \
  "[ \$d_rc -ne 0 ] && [ \"\$first\" = 'BREACH: default branch main moved' ] && ! grep -q Terminated <<<\"\$d_out\""
# tr_TR prints the timeout with a comma. BSD sleep then returns at once and
# the old timer killed the worker, so this line was not the breach. The
# locale is exported only in a subshell, so the checks after this one keep
# the caller's mark. Skip where the locale is absent.
locale -a > "$tmp/locales.txt" 2>/dev/null || true
if grep -qx 'tr_TR.UTF-8' "$tmp/locales.txt"; then
  d_new fixmovelocale
  d_run ok grok "" delegate "add a line"
  dbr=$(git -C "$dproj" symbolic-ref --short HEAD)
  before_main=$(git -C "$dproj" rev-parse refs/heads/main)
  (
    export LC_ALL=tr_TR.UTF-8 LANG=tr_TR.UTF-8
    d_run move grok "" delegate "move main"
    printf '%s\n' "$d_rc" > "$tmp/locale-rc"
    printf '%s\n' "$d_out" > "$tmp/locale-out"
  )
  d_rc=$(cat "$tmp/locale-rc")
  d_out=$(cat "$tmp/locale-out")
  first=${d_out%%$'\n'*}
  after_main=$(git -C "$dproj" rev-parse refs/heads/main)
  check "a comma decimal mark still reports a fix round that moves main, first" \
    "[ \$d_rc -ne 0 ] && [ \"\$first\" = 'BREACH: default branch main moved' ] && [ \"\$before_main\" != \"\$after_main\" ] && [ \"\$(git -C \"\$dproj\" symbolic-ref --short HEAD)\" != \"\$dbr\" ] && [ \"\$(git -C \"\$dproj\" branch --list 'delegate/*' | wc -l | tr -d ' ')\" = 1 ]"
fi
d_new fixside
d_run ok grok "" delegate "add a line"
d_run branch grok "" delegate "add a branch"
first=${d_out%%$'\n'*}
check "a fix round that adds a branch is still a breach" \
  "[ \$d_rc -ne 0 ] && [ \"\$first\" = 'BREACH: branch list changed' ] && git -C \"\$dproj\" show-ref --verify --quiet refs/heads/from-the-worker"
d_migration() {
  d_new "$1"
  git -C "$dproj" checkout -qb migration
  printf 'on the migration\n' >> "$dproj/README.md"
  git -C "$dproj" add README.md
  git -C "$dproj" commit -qm "chore: migration"
}
d_new nobase
DELEGATE_BASE=no-such d_run ok grok "" delegate "add a line"
check "a DELEGATE_BASE that does not exist is refused in one line" \
  "[ \$d_rc -ne 0 ] && d_one && grep -qx 'refuses: DELEGATE_BASE no-such does not exist' <<<\"\$d_out\" && [ -z \"\$(git -C \"\$dproj\" branch --list 'delegate/*')\" ]"
d_migration noton
git -C "$dproj" checkout -q main
DELEGATE_BASE=migration d_run ok grok "" delegate "add a line"
check "with DELEGATE_BASE set, the job must already be on that branch" \
  "[ \$d_rc -ne 0 ] && d_one && grep -qx 'refuses: not on the base branch (main; base is migration)' <<<\"\$d_out\" && [ -z \"\$(git -C \"\$dproj\" branch --list 'delegate/*')\" ]"
d_migration frombase
DELEGATE_BASE=migration d_run ok grok "" delegate "add a line"
dbr=$(git -C "$dproj" symbolic-ref --short HEAD)
recorded=$(git -C "$dproj" config --get "branch.${dbr}.delegateBase")
dparent=$(git -C "$dproj" rev-parse HEAD^)
dmig=$(git -C "$dproj" rev-parse migration)
check "a job starts from DELEGATE_BASE and records branch.<name>.delegateBase" \
  "[ \$d_rc -eq 0 ] && [ \"\$recorded\" = migration ] && [ \"\$dparent\" = \"\$dmig\" ] && ! git -C \"\$dproj\" cat-file -e main:worker-did.txt && git -C \"\$dproj\" cat-file -e \"\$dbr:worker-did.txt\""
d_run ok "" "" delegate-accept
check "accept fast-forwards the recorded base and leaves the default branch" \
  "[ \$d_rc -eq 0 ] && grep -qx \"accepted \$dbr onto migration\" <<<\"\$d_out\" && [ \"\$(git -C \"\$dproj\" symbolic-ref --short HEAD)\" = migration ] && git -C \"\$dproj\" cat-file -e migration:worker-did.txt && ! git -C \"\$dproj\" cat-file -e main:worker-did.txt && [ -z \"\$(git -C \"\$dproj\" branch --list 'delegate/*')\" ]"
d_new acceptwt
git -C "$dproj" checkout -qb migration
printf 'on the migration\n' >> "$dproj/README.md"
git -C "$dproj" add README.md
git -C "$dproj" commit -qm "chore: migration"
git -C "$dproj" checkout -q main
side="$tmp/delegate-accept-wt"
rm -rf "$side"
git -C "$dproj" worktree add -q "$side" migration
d_out=$(env -u WORKER -u WORKER_MODEL -u DELEGATE_TIMEOUT -u DELEGATE_IDLE -u WORKER_BIN -u DELEGATE_YES -u WORKER_LADDER \
  HOME="$dhome" PATH="$dbin:$PATH" FAKE_WORKER_PROMPT="$dprompt" FAKE_WORKER_MODE=ok \
  WORKER=grok DELEGATE_BASE=migration \
  just -f "$root/Justfile" -d "$side" delegate "add a line" 2>&1) && d_rc=0 || d_rc=$?
dbr=$(git -C "$side" symbolic-ref --short HEAD)
d_out=$(env -u WORKER -u DELEGATE_BASE HOME="$dhome" just -f "$root/Justfile" -d "$dproj" delegate-accept 2>&1) && d_rc=0 || d_rc=$?
main_now=$(git -C "$dproj" symbolic-ref --short HEAD)
side_now=$(git -C "$side" symbolic-ref --short HEAD)
check "accept from the main worktree fast-forwards the lane and does not switch main" \
  "[ \$d_rc -eq 0 ] && [ \"\$main_now\" = main ] && [ \"\$side_now\" = migration ] && git -C \"\$dproj\" cat-file -e migration:worker-did.txt && ! git -C \"\$dproj\" cat-file -e main:worker-did.txt && [ -z \"\$(git -C \"\$dproj\" branch --list 'delegate/*')\" ] && grep -qx \"accepted \$dbr onto migration\" <<<\"\$d_out\""
git -C "$dproj" worktree remove --force "$side" 2>/dev/null || true
d_new busybase
d_run ok grok "" delegate "add a line"
dbr=$(git -C "$dproj" symbolic-ref --short HEAD)
mainwt="$tmp/delegate-busy-main"
rm -rf "$mainwt"
git -C "$dproj" worktree add -q "$mainwt" main
d_out=$(env -u WORKER -u DELEGATE_BASE HOME="$dhome" just -f "$root/Justfile" -d "$dproj" delegate-accept 2>&1) && d_rc=0 || d_rc=$?
lane_branch=$(git -C "$dproj" symbolic-ref -q --short HEAD || echo detached)
main_now=$(git -C "$mainwt" symbolic-ref --short HEAD)
check "accept detaches the lane when the base is checked out elsewhere, and main stays" \
  "[ \$d_rc -eq 0 ] && [ \"\$main_now\" = main ] && [ \"\$lane_branch\" = detached ] && git -C \"\$mainwt\" cat-file -e main:worker-did.txt && git -C \"\$dproj\" cat-file -e HEAD:worker-did.txt && [ -z \"\$(git -C \"\$dproj\" branch --list 'delegate/*')\" ] && grep -qx \"accepted \$dbr onto main\" <<<\"\$d_out\""
git -C "$dproj" worktree remove --force "$mainwt" 2>/dev/null || true
d_migration basedrop
DELEGATE_BASE=migration d_run ok grok "" delegate "add a line"
nbr=$(git -C "$dproj" symbolic-ref --short HEAD)
d_out=$(printf 'y\n' | env -u WORKER -u DELEGATE_BASE HOME="$dhome" just -f "$root/Justfile" -d "$dproj" delegate-drop 2>&1) && d_rc=0 || d_rc=$?
check "drop returns to the recorded base" \
  "[ \$d_rc -eq 0 ] && grep -qx \"dropped \$nbr\" <<<\"\$d_out\" && [ \"\$(git -C \"\$dproj\" symbolic-ref --short HEAD)\" = migration ] && [ -z \"\$(git -C \"\$dproj\" branch --list 'delegate/*')\" ] && ! git -C \"\$dproj\" cat-file -e HEAD:worker-did.txt"
d_migration breachbase
FAKE_WORKER_TARGET=migration DELEGATE_BASE=migration d_run movebase grok "" delegate "move the base"
first=${d_out%%$'\n'*}
check "with DELEGATE_BASE set, moving that branch is the breach" \
  "[ \$d_rc -ne 0 ] && [ \"\$first\" = 'BREACH: base branch migration moved' ] && ! grep -q 'default branch' <<<\"\$d_out\""
d_migration movemain
DELEGATE_BASE=migration d_run move grok "" delegate "move main"
check "with DELEGATE_BASE set, moving the default branch is not that breach" \
  "[ \$d_rc -eq 0 ] && ! grep -q '^BREACH:' <<<\"\$d_out\""
d_migration fixbase
DELEGATE_BASE=migration d_run ok grok "" delegate "add a line"
FAKE_WORKER_TARGET=migration d_run movebase grok "" delegate "move the base again"
first=${d_out%%$'\n'*}
check "a fix round protects the recorded base when DELEGATE_BASE is unset" \
  "[ \$d_rc -ne 0 ] && [ \"\$first\" = 'BREACH: base branch migration moved' ] && ! grep -q Terminated <<<\"\$d_out\""
# n-8dbc9e. Three cases: another branch refuses before a worker; the same
# branch is still a fix round; a fresh run from main still starts there.
d_migration otherbase
git -C "$dproj" checkout -q main
d_run ok grok "" delegate "add a line"
dbr=$(git -C "$dproj" symbolic-ref --short HEAD)
n8_prompt=$(cksum < "$dprompt")
n8_ahead=$(git -C "$dproj" rev-list --count main..HEAD)
DELEGATE_BASE=migration d_run ok grok "" delegate "add another line"
n8_prompt2=$(cksum < "$dprompt")
n8_ahead2=$(git -C "$dproj" rev-list --count main..HEAD)
n8_count=$(git -C "$dproj" branch --list 'delegate/*' | wc -l | tr -d ' ')
check "on a delegate branch, DELEGATE_BASE naming another branch is refused before a worker" \
  "[ \$d_rc -ne 0 ] && d_one && grep -qx \"refuses: on \$dbr but DELEGATE_BASE is migration; unset DELEGATE_BASE to fix this branch, or checkout migration to start from it\" <<<\"\$d_out\" && [ \"\$(git -C \"\$dproj\" symbolic-ref --short HEAD)\" = \"\$dbr\" ] && [ \"\$n8_ahead2\" = \"\$n8_ahead\" ] && [ \"\$n8_ahead\" = 1 ] && [ \"\$n8_prompt2\" = \"\$n8_prompt\" ] && [ \"\$n8_count\" = 1 ] && [ -z \"\$(git -C \"\$dproj\" status --porcelain)\" ]"
d_new samebase
d_run ok grok "" delegate "add a line"
dbr=$(git -C "$dproj" symbolic-ref --short HEAD)
DELEGATE_BASE=$dbr d_run fix grok "" delegate "fix the line"
n8_count=$(git -C "$dproj" branch --list 'delegate/*' | wc -l | tr -d ' ')
n8_ahead=$(git -C "$dproj" rev-list --count main..HEAD)
check "a fix round with DELEGATE_BASE set to this same branch stays here" \
  "[ \$d_rc -eq 0 ] && [ \"\$(git -C \"\$dproj\" symbolic-ref --short HEAD)\" = \"\$dbr\" ] && [ \"\$n8_count\" = 1 ] && [ \"\$n8_ahead\" = 2 ] && ! grep -q '^BREACH:' <<<\"\$d_out\" && grep -q 'worker fixed the task' <<<\"\$d_out\" && grep -q 'worker did the task' <<<\"\$d_out\" && grep -qx 'tree: clean' <<<\"\$d_out\""
d_new frommain
d_run ok grok "" delegate "add a line"
dbr=$(git -C "$dproj" symbolic-ref --short HEAD)
n8_parent=$(git -C "$dproj" rev-parse HEAD^)
n8_main=$(git -C "$dproj" rev-parse main)
n8_count=$(git -C "$dproj" branch --list 'delegate/*' | wc -l | tr -d ' ')
check "a fresh run from main still starts a delegate branch there" \
  "[ \$d_rc -eq 0 ] && case \"\$dbr\" in delegate/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-add-a-line) ;; *) false ;; esac && [ \"\$n8_parent\" = \"\$n8_main\" ] && [ \"\$n8_count\" = 1 ] && git -C \"\$dproj\" cat-file -e \"\$dbr:worker-did.txt\" && ! grep -q '^BREACH:' <<<\"\$d_out\" && grep -qx 'tree: clean' <<<\"\$d_out\""
d_new dropyes
d_run ok grok "" delegate "add a line"
nbr=$(git -C "$dproj" symbolic-ref --short HEAD)
d_out=$(env -u WORKER -u DELEGATE_YES HOME="$dhome" just -f "$root/Justfile" -d "$dproj" delegate-drop --yes </dev/null 2>&1) && d_rc=0 || d_rc=$?
check "delegate-drop --yes deletes with no terminal and does not ask" \
  "[ \$d_rc -eq 0 ] && grep -qx \"dropped \$nbr\" <<<\"\$d_out\" && ! grep -q 'Delete ' <<<\"\$d_out\" && [ -z \"\$(git -C \"\$dproj\" branch --list 'delegate/*')\" ] && [ \"\$(git -C \"\$dproj\" symbolic-ref --short HEAD)\" = main ]"
d_new dropenv
d_run ok grok "" delegate "add a line"
nbr=$(git -C "$dproj" symbolic-ref --short HEAD)
d_out=$(env -u WORKER HOME="$dhome" DELEGATE_YES=1 just -f "$root/Justfile" -d "$dproj" delegate-drop </dev/null 2>&1) && d_rc=0 || d_rc=$?
check "DELEGATE_YES=1 deletes with no terminal and does not ask" \
  "[ \$d_rc -eq 0 ] && grep -qx \"dropped \$nbr\" <<<\"\$d_out\" && ! grep -q 'Delete ' <<<\"\$d_out\" && [ -z \"\$(git -C \"\$dproj\" branch --list 'delegate/*')\" ] && [ \"\$(git -C \"\$dproj\" symbolic-ref --short HEAD)\" = main ]"
d_new dropclosed
d_run ok grok "" delegate "add a line"
nbr=$(git -C "$dproj" symbolic-ref --short HEAD)
d_out=$(env -u WORKER -u DELEGATE_YES HOME="$dhome" just -f "$root/Justfile" -d "$dproj" delegate-drop </dev/null 2>&1) && d_rc=0 || d_rc=$?
if git -C "$dproj" show-ref --verify --quiet "refs/heads/$nbr"; then kept_branch=yes; else kept_branch=no; fi
check "without --yes, a closed stdin still asks once and keeps the branch" \
  "[ \$d_rc -ne 0 ] && grep -q \"Delete \$nbr\" <<<\"\$d_out\" && grep -q \"kept \$nbr\" <<<\"\$d_out\" && [ \"\$kept_branch\" = yes ]"

# spec 038. The fake prints events; it never calls a model. The dollar sum is
# 0.01 + 0.02 from the two step_finish events. The text event's cost of 9 is
# not part of the sum.
oc_argv_is() {
  local want="$1" line n=0
  while IFS= read -r line; do
    n=$((n+1))
    case "$n" in
      1) [ "$line" = run ] || return 1 ;;
      2) [ "$line" = --standalone ] || return 1 ;;
      3) [ "$line" = --auto ] || return 1 ;;
      4) [ "$line" = --format ] || return 1 ;;
      5) [ "$line" = json ] || return 1 ;;
      6) [ "$line" = -m ] || return 1 ;;
      7) [ "$line" = "$want" ] || return 1 ;;
      *) return 0 ;;
    esac
  done < "$dprompt.argv"
  return 1
}
oc_config_ok() {
  local cfg="$dprompt.config" path p
  path=$(cat "$dprompt.configpath")
  [ -n "$path" ] || return 1
  [ -f "$path" ] || return 1
  case "$path" in
    "$dhome/.cache/ai-backbone/delegate/"*) ;;
    *) return 1 ;;
  esac
  case "$path" in
    "$dproj"/*) return 1 ;;
  esac
  cmp -s "$path" "$cfg" || return 1
  grep -qF '"autoupdate": false' "$cfg" || return 1
  grep -qF '"update": "disable"' "$cfg" || return 1
  grep -qF '"*": "deny"' "$cfg" || return 1
  grep -qF '"edit": "allow"' "$cfg" || return 1
  grep -qF '"write": "allow"' "$cfg" || return 1
  grep -qF '"webfetch": "deny"' "$cfg" || return 1
  grep -qF '"websearch": "deny"' "$cfg" || return 1
  grep -qF '"external_directory": "deny"' "$cfg" || return 1
  grep -qF '"*": "allow"' "$cfg" || return 1
  for p in \
    "git push *" "git merge *" "git rebase *" "git checkout *" "git switch *" \
    "git reset *" "git branch -d *" "git branch -D *" "git tag *" \
    "just publish *" "just ship *" "just deploy *" "just release *" "just undo *" \
    "just delegate-accept *" "just delegate-drop *" \
    "gh *" "curl *" "ssh *" "rm *" \
    "sh *" "bash *" "zsh *" "eval *" "xargs *" "env *" \
    "security find-generic-password *" "security find-internet-password *" \
    "/usr/bin/security find-generic-password *" "/usr/bin/security find-internet-password *" \
    "secret-tool lookup *" "/usr/bin/secret-tool lookup *" \
    "just with-secret *" "ssh-add *" "/usr/bin/ssh-add *"
  do
    grep -qF "\"$p\": \"deny\"" "$cfg" || return 1
  done
  for p in \
    "**/.aws/**" "**/.appstoreconnect/**" "**/.ssh/**" \
    "**/.config/gh/hosts.yml" "**/.grok/auth.json" "**/.grok/mcp_credentials.json" \
    "**/brain/secrets/**" "**/brain/03-stack/**" "**/.env" "**/.envrc" \
    "**/ai-backbone/keystore/**" "**/ssh-agent.sock"
  do
    grep -qF "\"$p\": \"deny\"" "$cfg" || return 1
  done
  ! grep -q '.env.example' "$cfg" || return 1
  # spec 038: the catch-all deny is first, and inside shell the allow comes
  # before the denies (last match wins). spec 041: the same order inside read.
  awk '
    $0 ~ /"\*": "deny"/ && !d { d = NR }
    /"read"/ { r = 1 }
    r && $0 ~ /"\*": "allow"/ && !ra { ra = NR }
    ra && $0 ~ /"\*\*\/\.env": "deny"/ && NR > ra { read_ok = 1; r = 0 }
    /"shell"/ { s = 1 }
    s && $0 ~ /"\*": "allow"/ { a = NR; s = 0 }
    a && $0 ~ /"sh \*": "deny"/ && NR > a { sh_ok = 1 }
    a && $0 ~ /"security find-generic-password \*": "deny"/ && NR > a { sec_ok = 1 }
    END { exit !(d && ra && ra > d && read_ok && sh_ok && sec_ok) }
  ' "$cfg"
}
oc_events_ok() {
  local want="$1" f n
  dlog=""
  for f in "$dhome/.cache/ai-backbone/delegate/$(basename "$dproj")"/*.log; do
    [ -f "$f" ] || continue
    dlog=$f
  done
  [ -n "$dlog" ] || return 1
  case "$dlog" in
    "$dhome/.cache/ai-backbone/delegate/"*) ;;
    *) return 1 ;;
  esac
  [ -z "$(find "$dproj" -name '*.log' -type f)" ] || return 1
  grep -qF '"cost":9' "$dlog" || return 1
  grep -qF '"cost":0.01' "$dlog" || return 1
  grep -qF '"cost":0.02' "$dlog" || return 1
  n=$(grep -c '"type":"step_finish"' "$dlog" || true)
  [ "$n" = 2 ] || return 1
  grep -qxF "$want" <<< "$d_out" || return 1
  [ "$(tail -n 1 "$dlog")" = "$want" ]
}
d_new ocfirst
d_run ok opencode "" delegate "add a line"
dbr=$(git -C "$dproj" symbolic-ref --short HEAD)
rung=$(git -C "$dproj" config --get "branch.${dbr}.delegateRung" 2>/dev/null || true)
check "opencode's first try runs the first ladder model, with the preamble, and the report ends on the summed cost" \
  "[ \$d_rc -eq 0 ] && oc_argv_is 'opencode-go/deepseek-v4.1-flash' && [ \"\$(cat \"\$dprompt.model\")\" = 'opencode-go/deepseek-v4.1-flash' ] && [ \"\$(cat \"\$dprompt.fmt\")\" = json ] && [ \"\$(cat \"\$dprompt.standalone\")\" = 1 ] && [ \"\$(cat \"\$dprompt.auto\")\" = 1 ] && grep -q 'Read AGENTS.md' \"\$dprompt\" && grep -q \"You are on branch \$dbr; stay on it.\" \"\$dprompt\" && grep -q 'just save' \"\$dprompt\" && grep -q 'just publish' \"\$dprompt\" && grep -q 'at most 15 lines' \"\$dprompt\" && [ \"\$(tail -n 1 \"\$dprompt\")\" = 'add a line' ] && [ \"\$rung\" = 0 ] && oc_events_ok 'cost: \$0.03 on opencode-go/deepseek-v4.1-flash, 2 steps'"
check "the preamble opencode receives says never begin a command with a variable assignment" \
  "grep -Fq 'Never begin a command with a variable assignment; put multi-step logic in a recipe or a test file.' \"\$dprompt\""
check "the config the fake receives denies the grok list and the shell wrappers, turns autoupdate off, and blocks web fetch and outside paths" \
  "oc_config_ok && [ \"\$(cat \"\$dprompt.projectdisable\")\" = 1 ]"
check "the default ladder is the two opencode-go models and does not name kimi-k3 (n-061941)" \
  "grep -q 'ladder=\"opencode-go/deepseek-v4.1-flash,opencode-go/glm-5.3\"' '$root/.ai-backbone/core.just' && ! grep -q kimi-k3 '$root/.agents/skills/delegate/SKILL.md' '$root/docs/01-getting-started.md'"
d_run fix opencode "" delegate "fix the line"
rung=$(git -C "$dproj" config --get "branch.${dbr}.delegateRung" 2>/dev/null || true)
check "a fix round that succeeded stays on the same model (n-061941)" \
  "[ \$d_rc -eq 0 ] && [ \"\$(cat \"\$dprompt.model\")\" = 'opencode-go/deepseek-v4.1-flash' ] && [ \"\$rung\" = 0 ] && [ \"\$(git -C \"\$dproj\" symbolic-ref --short HEAD)\" = \"\$dbr\" ]"
d_run fail opencode "" delegate "break it"
rung=$(git -C "$dproj" config --get "branch.${dbr}.delegateRung" 2>/dev/null || true)
check "a failed round stores the next ladder index and does not switch model mid-round (n-061941)" \
  "[ \$d_rc -ne 0 ] && [ \"\$(cat \"\$dprompt.model\")\" = 'opencode-go/deepseek-v4.1-flash' ] && [ \"\$rung\" = 1 ]"
d_run ok opencode "" delegate "after the failure"
rung=$(git -C "$dproj" config --get "branch.${dbr}.delegateRung" 2>/dev/null || true)
check "the round after a failure climbs to the last model of the default ladder" \
  "[ \$d_rc -eq 0 ] && [ \"\$(cat \"\$dprompt.model\")\" = 'opencode-go/glm-5.3' ] && [ \"\$rung\" = 1 ] && oc_events_ok 'cost: \$0.03 on opencode-go/glm-5.3, 2 steps'"
d_run fail opencode "" delegate "break again"
rung=$(git -C "$dproj" config --get "branch.${dbr}.delegateRung" 2>/dev/null || true)
check "a failure on the last model stores the index past the ladder" \
  "[ \$d_rc -ne 0 ] && [ \"\$(cat \"\$dprompt.model\")\" = 'opencode-go/glm-5.3' ] && [ \"\$rung\" = 2 ]"
calls=$(wc -l < "$dprompt.models" | tr -d ' ')
model_before=$(cat "$dprompt.model")
d_run fix opencode "" delegate "one more"
calls_after=$(wc -l < "$dprompt.models" | tr -d ' ')
model_after=$(cat "$dprompt.model")
rung=$(git -C "$dproj" config --get "branch.${dbr}.delegateRung" 2>/dev/null || true)
check "past the last model, delegate refuses in one line and does not run the worker" \
  "[ \$d_rc -ne 0 ] && d_one && grep -qx 'refuses: past the last model of the ladder; two failed tries go to the maintainer' <<<\"\$d_out\" && [ \"\$calls_after\" = \"\$calls\" ] && [ \"\$model_after\" = \"\$model_before\" ] && [ \"\$rung\" = 2 ]"
d_new ocstale
stale="delegate/$(LC_ALL=C date +%Y-%m-%d)-add-a-line"
git -C "$dproj" config "branch.${stale}.delegateRung" 3
d_run ok opencode "" delegate "add a line"
dbr=$(git -C "$dproj" symbolic-ref --short HEAD)
rung=$(git -C "$dproj" config --get "branch.${dbr}.delegateRung" 2>/dev/null || true)
check "a new branch starts at the first model even when a dropped branch left a rung" \
  "[ \$d_rc -eq 0 ] && [ \"\$dbr\" = \"\$stale\" ] && [ \"\$(cat \"\$dprompt.model\")\" = 'opencode-go/deepseek-v4.1-flash' ] && [ \"\$rung\" = 0 ]"
d_new ocpin
d_run ok opencode "opencode-go/pinned" delegate "add a line"
dbr=$(git -C "$dproj" symbolic-ref --short HEAD)
rung=$(git -C "$dproj" config --get "branch.${dbr}.delegateRung" 2>/dev/null || true)
check "WORKER_MODEL pins the opencode model and does not climb" \
  "[ \$d_rc -eq 0 ] && [ \"\$(cat \"\$dprompt.model\")\" = 'opencode-go/pinned' ] && [ -z \"\$rung\" ] && oc_events_ok 'cost: \$0.03 on opencode-go/pinned, 2 steps'"
d_run fix opencode "opencode-go/pinned" delegate "fix the line"
rung=$(git -C "$dproj" config --get "branch.${dbr}.delegateRung" 2>/dev/null || true)
check "a fix round with WORKER_MODEL stays on that model" \
  "[ \$d_rc -eq 0 ] && [ \"\$(cat \"\$dprompt.model\")\" = 'opencode-go/pinned' ] && [ -z \"\$rung\" ]"
d_new occustom
WORKER_LADDER='opencode-go/one, opencode-go/two' d_run ok opencode "" delegate "add a line"
check "WORKER_LADDER's first model is the first try, and a space after a comma is ignored" \
  "[ \$d_rc -eq 0 ] && [ \"\$(cat \"\$dprompt.model\")\" = 'opencode-go/one' ]"
WORKER_LADDER='opencode-go/one, opencode-go/two' d_run fix opencode "" delegate "fix the line"
check "a successful fix round on a custom ladder stays on the first model" \
  "[ \$d_rc -eq 0 ] && [ \"\$(cat \"\$dprompt.model\")\" = 'opencode-go/one' ]"
WORKER_LADDER='opencode-go/one, opencode-go/two' d_run fail opencode "" delegate "break it"
WORKER_LADDER='opencode-go/one, opencode-go/two' d_run ok opencode "" delegate "after the failure"
check "WORKER_LADDER's next model is the round after a failure" \
  "[ \$d_rc -eq 0 ] && [ \"\$(cat \"\$dprompt.model\")\" = 'opencode-go/two' ]"
WORKER_LADDER='opencode-go/one, opencode-go/two' d_run fail opencode "" delegate "break again"
calls=$(wc -l < "$dprompt.models" | tr -d ' ')
WORKER_LADDER='opencode-go/one, opencode-go/two' d_run fix opencode "" delegate "past it"
calls_after=$(wc -l < "$dprompt.models" | tr -d ' ')
check "past a short ladder, delegate refuses and does not run the worker" \
  "[ \$d_rc -ne 0 ] && d_one && grep -qx 'refuses: past the last model of the ladder; two failed tries go to the maintainer' <<<\"\$d_out\" && [ \"\$calls_after\" = \"\$calls\" ]"
d_new octime
t0=$SECONDS
d_out=$(env -u WORKER -u WORKER_MODEL -u WORKER_LADDER -u DELEGATE_IDLE -u WORKER_BIN -u DELEGATE_BASE -u DELEGATE_YES \
  HOME="$dhome" PATH="$dbin:$PATH" FAKE_WORKER_MODE=timeout FAKE_WORKER_PROMPT="$dprompt" FAKE_WORKER_GO="$dgo" \
  WORKER=opencode DELEGATE_TIMEOUT=0.05 just -f "$root/Justfile" -d "$dproj" delegate "sleep it" 2>&1) && d_rc=0 || d_rc=$?
elapsed=$((SECONDS - t0))
dbr=$(git -C "$dproj" symbolic-ref --short HEAD)
rung=$(git -C "$dproj" config --get "branch.${dbr}.delegateRung" 2>/dev/null || true)
check "a round that stops at DELEGATE_TIMEOUT stays on the first model and does not climb (n-061941)" \
  "[ \$d_rc -eq 124 ] && [ \$elapsed -lt 15 ] && grep -qx 'exit status: timeout' <<<\"\$d_out\" && [ \"\$(cat \"\$dprompt.model\")\" = 'opencode-go/deepseek-v4.1-flash' ] && [ \"\$rung\" = 0 ] && ! grep -q finished <<<\"\$d_out\""
d_run ok opencode "" delegate "after the timeout"
rung=$(git -C "$dproj" config --get "branch.${dbr}.delegateRung" 2>/dev/null || true)
check "the round after a timeout uses the same model" \
  "[ \$d_rc -eq 0 ] && [ \"\$(cat \"\$dprompt.model\")\" = 'opencode-go/deepseek-v4.1-flash' ] && [ \"\$rung\" = 0 ]"
d_new ocempty
WORKER_LADDER= d_run ok opencode "" delegate "add a line"
check "an empty WORKER_LADDER is refused in one line and makes no branch" \
  "[ \$d_rc -ne 0 ] && d_one && grep -qx 'refuses: WORKER_LADDER has no model' <<<\"\$d_out\" && [ -z \"\$(git -C \"\$dproj\" branch --list 'delegate/*')\" ]"
WORKER_LADDER=' , ' d_run ok opencode "" delegate "add a line"
check "a WORKER_LADDER of only commas is refused and makes no branch" \
  "[ \$d_rc -ne 0 ] && d_one && grep -qx 'refuses: WORKER_LADDER has no model' <<<\"\$d_out\" && [ -z \"\$(git -C \"\$dproj\" branch --list 'delegate/*')\" ]"
d_new ocgrok
WORKER_LADDER='opencode-go/one,opencode-go/two' d_run ok grok "" delegate "add a line"
check "grok ignores WORKER_LADDER and prints no cost line" \
  "[ \$d_rc -eq 0 ] && [ -z \"\$(cat \"\$dprompt.model\")\" ] && [ \"\$(cat \"\$dprompt.fmt\")\" = plain ] && ! grep -q '^cost:' <<<\"\$d_out\""
d_new ocbin
mkdir -p "$dhome/.opencode/bin" "$tmp/delegate-plain"
cp "$dbin/opencode" "$dhome/.opencode/bin/opencode"
chmod +x "$dhome/.opencode/bin/opencode"
# A copied exe does not start: its libraries sit beside the real one, and
# Git Bash copies when it cannot link (spec 020). The new task strip and the
# ref hook both run perl, so a copied perl.exe ended the recipe before the
# worker. A script runs the real binary. This folder still has no opencode.
for tool in just git perl; do
  src=$(command -v "$tool")
  printf '#!/bin/sh\nexec "%s" "$@"\n' "$src" > "$tmp/delegate-plain/$tool"
  chmod +x "$tmp/delegate-plain/$tool"
  if command -v cygpath >/dev/null 2>&1; then
    printf '@echo off\r\n"%s" %%*\r\n' "$(cygpath -w "$src")" > "$tmp/delegate-plain/$tool.cmd"
  fi
done
rm -f "$tmp/delegate-binlog"
# Homebrew's bin holds the real opencode next to just. This path does not,
# or the fallback would never run and a live model would.
d_out=$(env -u WORKER -u WORKER_BIN -u WORKER_MODEL -u WORKER_LADDER -u OPENCODE_CONFIG -u OPENCODE_CONFIG_PROJECT_DISABLE \
  HOME="$dhome" PATH="$tmp/delegate-plain:/usr/bin:/bin" \
  FAKE_WORKER_PROMPT="$dprompt" FAKE_WORKER_MODE=ok FAKE_WORKER_BINLOG="$tmp/delegate-binlog" \
  WORKER=opencode just -f "$root/Justfile" -d "$dproj" delegate "use opencode" 2>&1) && d_rc=0 || d_rc=$?
check "an opencode that lives only at ~/.opencode/bin/opencode is the binary the adapter runs" \
  "[ \$d_rc -eq 0 ] && [ \"\$(cat \"\$tmp/delegate-binlog\")\" = \"\$dhome/.opencode/bin/opencode\" ] && [ \"\$(cat \"\$dprompt.model\")\" = 'opencode-go/deepseek-v4.1-flash' ]"
rm -f "$dhome/.opencode/bin/opencode"
d_new ocstatus
d_run ok opencode "" delegate "add a line"
dst=$(env -u WORKER HOME="$dhome" PATH="$dbin:$PATH" just -f "$root/Justfile" -d "$dproj" delegate-status 2>&1 || true)
check "delegate-status shows the model and the cost of the last opencode run" \
  "grep -qx 'job: none' <<<\"\$dst\" && grep -qx 'last run: cost: \$0.03 on opencode-go/deepseek-v4.1-flash, 2 steps' <<<\"\$dst\" && ! grep -q 'opencode service is running' <<<\"\$dst\""
d_new ocstopped
dst=$(env -u WORKER HOME="$dhome" PATH="$dbin:$PATH" FAKE_OPENCODE_STATUS=stopped \
  just -f "$root/Justfile" -d "$dproj" delegate-status 2>&1 || true)
check "delegate-status is quiet when the opencode service is stopped (n-20e061)" \
  "! grep -q 'opencode service is running' <<<\"\$dst\""
d_new ocrunning
dst=$(env -u WORKER HOME="$dhome" PATH="$dbin:$PATH" FAKE_OPENCODE_STATUS=http://127.0.0.1:4096 \
  just -f "$root/Justfile" -d "$dproj" delegate-status 2>&1 || true)
check "delegate-status warns when the opencode service is running (n-20e061)" \
  "grep -qx 'opencode service is running: a command without --standalone resumes its sessions' <<<\"\$dst\""
check "the opencode run passes --standalone, and the docs name stats (n-20e061)" \
  "grep -q 'run --standalone --auto --format json' '$root/.ai-backbone/core.just' && grep -q 'opencode stats' '$root/.agents/skills/delegate/SKILL.md' && grep -q 'including \`opencode stats\`' '$root/docs/01-getting-started.md'"

# kimi (spec 040). The fake never calls a model. Login is a file in the
# temporary home: this suite must not read or write the real ~/.kimi-code.
kimi_login_files() {
  mkdir -p "$dhome/.kimi-code/credentials"
  printf '%s\n' '{"access_token":"fixture"}' > "$dhome/.kimi-code/credentials/oauth.json"
}
kimi_seed_config() {
  mkdir -p "$dhome/.kimi-code"
  cat > "$dhome/.kimi-code/config.toml" << 'EOF'
# user keep
[permission]
dangerous_command_guard = false

[[permission.rules]]
decision = "allow"
pattern = "Bash(echo *)"

# BEGIN ai-backbone delegate
[[permission.rules]]
decision = "deny"
pattern = "Bash(stale-should-go)"
# END ai-backbone delegate
EOF
}
kimi_rules_ok() {
  local cfg="$dhome/.kimi-code/config.toml"
  [ -f "$cfg" ] || return 1
  [ "$(grep -c '^# BEGIN ai-backbone delegate$' "$cfg")" -eq 1 ] || return 1
  [ "$(grep -c '^# END ai-backbone delegate$' "$cfg")" -eq 1 ] || return 1
  grep -qxF 'pattern = "Bash(git push)"' "$cfg" || return 1
  grep -qxF 'pattern = "Bash(git push **)"' "$cfg" || return 1
  grep -qxF 'pattern = "Bash(just carry)"' "$cfg" || return 1
  grep -qxF 'pattern = "Bash(just publish)"' "$cfg" || return 1
  grep -qxF 'pattern = "Bash(just delegate-accept)"' "$cfg" || return 1
  grep -qxF 'pattern = "Bash(just delegate-accept **)"' "$cfg" || return 1
  grep -qxF 'pattern = "Bash(just delegate-drop)"' "$cfg" || return 1
  grep -qxF 'pattern = "Bash(just delegate-drop **)"' "$cfg" || return 1
  grep -qxF 'pattern = "Bash(git merge)"' "$cfg" || return 1
  grep -qxF 'pattern = "Bash(sh)"' "$cfg" || return 1
  grep -qxF 'pattern = "Bash(sh **)"' "$cfg" || return 1
  grep -qxF 'pattern = "WebSearch"' "$cfg" || return 1
  grep -qxF 'pattern = "FetchURL"' "$cfg" || return 1
  grep -qxF 'pattern = "Read(~/.aws/**)"' "$cfg" || return 1
  grep -qxF 'pattern = "Bash(security find-generic-password)"' "$cfg" || return 1
  grep -qxF 'pattern = "Bash(secret-tool lookup)"' "$cfg" || return 1
  grep -qxF 'pattern = "Bash(/usr/bin/secret-tool lookup)"' "$cfg" || return 1
  grep -qxF 'pattern = "Bash(just with-secret)"' "$cfg" || return 1
  grep -qxF 'pattern = "Bash(ssh-add)"' "$cfg" || return 1
  grep -qxF 'pattern = "Bash(/usr/bin/ssh-add)"' "$cfg" || return 1
  grep -qxF 'pattern = "Read(**/ssh-agent.sock)"' "$cfg" || return 1
  grep -qxF 'pattern = "Read(**/.envrc)"' "$cfg" || return 1
  grep -qxF 'pattern = "Read(**/ai-backbone/keystore/**)"' "$cfg" || return 1
  grep -qxF 'pattern = "Write(.env)"' "$cfg" || return 1
  grep -qxF 'pattern = "Edit(**/.env)"' "$cfg" || return 1
  grep -qxF 'pattern = "Read(brain/03-stack/**)"' "$cfg" || return 1
  grep -qx 'decision = "deny"' "$cfg" || return 1
  ! grep -q 'stale-should-go' "$cfg" || return 1
  ! grep -qF 'Bash(sh*)' "$cfg" || return 1
  grep -qx 'dangerous_command_guard = false' "$cfg" || return 1
  [ "$(grep -c '^\[permission\]$' "$cfg")" -eq 1 ] || return 1
  awk '
    $0 == "pattern = \"Bash(git push)\"" && !p { p = NR }
    $0 == "pattern = \"Bash(echo *)\"" { e = NR }
    END { exit !(p && e && p < e) }
  ' "$cfg" || return 1
  awk '
    /^# BEGIN ai-backbone delegate$/ { inb = 1; next }
    /^# END ai-backbone delegate$/ { inb = 0; next }
    $0 == "pattern = \"Bash(echo *)\"" { if (inb) bad = 1; else keep = 1 }
    inb && $0 == "decision = \"allow\"" { bad = 1 }
    END { exit !(keep && !bad) }
  ' "$cfg"
}
kimi_log() {
  local f
  dlog=""
  for f in "$dhome/.cache/ai-backbone/delegate/$(basename "$dproj")"/*.log; do
    [ -f "$f" ] || continue
    dlog=$f
  done
  [ -n "$dlog" ] || return 1
  case "$dlog" in
    "$dhome/.cache/ai-backbone/delegate/"*) ;;
    *) return 1 ;;
  esac
  [ -z "$(find "$dproj" -name '*.log' -type f)" ]
}
rm -rf "$dhome/.kimi-code"
d_new kiminone
d_run ok kimi "" delegate "add a line"
check "kimi that is not logged in is refused in one line, and no branch or config is written" \
  "[ \$d_rc -ne 0 ] && d_one && grep -qx 'kimi is not logged in: run kimi login' <<<\"\$d_out\" && [ -z \"\$(git -C \"\$dproj\" branch --list 'delegate/*')\" ] && [ ! -e \"\$dhome/.kimi-code/config.toml\" ] && [ ! -f \"\$dprompt\" ]"
mkdir -p "$dhome/.kimi-code"
printf '%s\n' 'api_key = ""' > "$dhome/.kimi-code/config.toml"
d_new kimiemptykey
d_run ok kimi "" delegate "add a line"
check "an empty kimi api_key is not a login, and the config is left untouched" \
  "[ \$d_rc -ne 0 ] && grep -qx 'kimi is not logged in: run kimi login' <<<\"\$d_out\" && [ -z \"\$(git -C \"\$dproj\" branch --list 'delegate/*')\" ] && [ ! -f \"\$dprompt\" ] && grep -qx 'api_key = \"\"' \"\$dhome/.kimi-code/config.toml\" && ! grep -q 'BEGIN ai-backbone delegate' \"\$dhome/.kimi-code/config.toml\""
rm -rf "$dhome/.kimi-code"
mkdir -p "$dhome/.kimi-code"
printf '%s\n' 'api_key = "fixture-key"' > "$dhome/.kimi-code/config.toml"
d_new kimikey
d_run ok kimi "" delegate "add a line"
check "a non-empty kimi api_key counts as logged in" \
  "[ \$d_rc -eq 0 ] && [ -f \"\$dprompt\" ] && [ -n \"\$(git -C \"\$dproj\" branch --list 'delegate/*')\" ]"
rm -rf "$dhome/.kimi-code"
d_new kimirun
kimi_login_files
kimi_seed_config
rules_before=0
DELEGATE_MODEL=k2 WORKER_LADDER='opencode-go/one,opencode-go/two' d_run ok kimi "should-not-pass" delegate "add a line"
dbr=$(git -C "$dproj" symbolic-ref --short HEAD)
rung=$(git -C "$dproj" config --get "branch.${dbr}.delegateRung" 2>/dev/null || true)
rules_before=$(grep -c '^\[\[permission.rules\]\]$' "$dhome/.kimi-code/config.toml")
check "kimi runs headless with the preamble, passes DELEGATE_MODEL as -m, and ignores the ladder and WORKER_MODEL" \
  "[ \$d_rc -eq 0 ] && [ -f \"\$dproj/worker-did.txt\" ] && [ \"\$(cat \"\$dprompt.fmt\")\" = stream-json ] && [ \"\$(cat \"\$dprompt.model\")\" = k2 ] && [ \"\$(cat \"\$dprompt.trust\")\" = 1 ] && [ \"\$(cat \"\$dprompt.guard\")\" = true ] && [ \"\$(cat \"\$dprompt.home\")\" = unset ] && [ \"\$(cat \"\$dprompt.configpath\")\" = \"\$dhome/.kimi-code/config.toml\" ] && grep -q 'Read AGENTS.md' \"\$dprompt\" && grep -q \"You are on branch \$dbr; stay on it.\" \"\$dprompt\" && grep -q 'just save' \"\$dprompt\" && grep -q 'just publish' \"\$dprompt\" && grep -q 'at most 15 lines' \"\$dprompt\" && [ \"\$(tail -n 1 \"\$dprompt\")\" = 'add a line' ] && [ -z \"\$rung\" ] && ! grep -q should-not-pass \"\$dprompt.argv\""
check "the preamble kimi receives says never begin a command with a variable assignment" \
  "grep -Fq 'Never begin a command with a variable assignment; put multi-step logic in a recipe or a test file.' \"\$dprompt\""
check "the kimi rules deny a publish and a push, keep the user's rule first-match behind them, and drop the stale block" \
  "kimi_rules_ok"
check "the kimi report is the last 15 lines of assistant text, and the stream-json log stays outside the repo" \
  "kimi_log && grep -q 'tool-line-should-not-be-the-report' \"\$dlog\" && grep -q '\"role\":\"assistant\"' \"\$dlog\" && grep -qx 'line-06' <<<\"\$d_out\" && grep -qx 'line-20' <<<\"\$d_out\" && ! grep -qx 'line-05' <<<\"\$d_out\" && ! grep -qx 'line-01' <<<\"\$d_out\" && ! grep -q 'tool-line-should-not-be-the-report' <<<\"\$d_out\""
d_run fix kimi "" delegate "fix the line"
rules_after=$(grep -c '^\[\[permission.rules\]\]$' "$dhome/.kimi-code/config.toml")
check "a second kimi run rewrites the deny block once and does not pass -m when DELEGATE_MODEL is unset" \
  "[ \$d_rc -eq 0 ] && [ \"\$rules_after\" = \"\$rules_before\" ] && kimi_rules_ok && [ -z \"\$(cat \"\$dprompt.model\")\" ] && ! grep -qx -- '-m' \"\$dprompt.argv\""
dst=$(env -u WORKER -u KIMI_CODE_HOME -u DELEGATE_MODEL HOME="$dhome" PATH="$dbin:$PATH" just -f "$root/Justfile" -d "$dproj" delegate-status 2>&1 || true)
check "delegate-status reads the kimi report from assistant content" \
  "grep -qx 'line-20' <<<\"\$dst\" && ! grep -qx 'line-01' <<<\"\$dst\" && ! grep -q 'tool-line-should-not-be-the-report' <<<\"\$dst\""
d_new kimibin
kimi_login_files
mkdir -p "$dhome/.kimi-code/bin" "$tmp/delegate-plain"
cp "$dbin/kimi" "$dhome/.kimi-code/bin/kimi"
chmod +x "$dhome/.kimi-code/bin/kimi"
for tool in just git perl; do
  src=$(command -v "$tool")
  printf '#!/bin/sh\nexec "%s" "$@"\n' "$src" > "$tmp/delegate-plain/$tool"
  chmod +x "$tmp/delegate-plain/$tool"
  if command -v cygpath >/dev/null 2>&1; then
    printf '@echo off\r\n"%s" %%*\r\n' "$(cygpath -w "$src")" > "$tmp/delegate-plain/$tool.cmd"
  fi
done
rm -f "$tmp/delegate-binlog"
# This path has no kimi. Homebrew's real binary is not on it, so the fallback
# is the only one, and a live `kimi -p` is never started.
d_out=$(env -u WORKER -u WORKER_BIN -u WORKER_MODEL -u DELEGATE_MODEL -u KIMI_CODE_HOME \
  -u KIMI_CODE_TRUST_WORKSPACE -u KIMI_CODE_DANGEROUS_COMMAND_GUARD \
  HOME="$dhome" PATH="$tmp/delegate-plain:/usr/bin:/bin" \
  FAKE_WORKER_PROMPT="$dprompt" FAKE_WORKER_MODE=ok FAKE_WORKER_BINLOG="$tmp/delegate-binlog" \
  WORKER=kimi just -f "$root/Justfile" -d "$dproj" delegate "use kimi" 2>&1) && d_rc=0 || d_rc=$?
check "a kimi that lives only at ~/.kimi-code/bin/kimi is the binary the adapter runs" \
  "[ \$d_rc -eq 0 ] && [ \"\$(cat \"\$tmp/delegate-binlog\")\" = \"\$dhome/.kimi-code/bin/kimi\" ] && [ \"\$(cat \"\$dprompt.fmt\")\" = stream-json ]"
rm -f "$dhome/.kimi-code/bin/kimi"

fi
if lane_wants github; then
section "a GitHub repository the backbone creates (n-baecb7)"
# A stub gh on PATH records every call and makes a bare repository where the
# real one adds origin. Nothing here reaches GitHub.
ghs="$tmp/ghs"; mkdir -p "$ghs/bin"
cat > "$ghs/bin/gh" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$GH_CALLS"
case "$1 $2" in
  "auth status") exit 0 ;;
  "repo create")
    git init -q --bare "$GH_REMOTE"
    git remote add origin "$GH_REMOTE"
    exit 0 ;;
  "api user") echo someone; exit 0 ;;
esac
exit 0
EOF
chmod +x "$ghs/bin/gh"
ghrun() { env -u AI_BACKBONE_OFFLINE PATH="$ghs/bin:$PATH" GH_CALLS="$tmp/gh-calls" GH_REMOTE="$tmp/gh-remote.git" "$@"; }
ghp="$tmp/gh-proj"
( cd "$root" && just new-project "$ghp" ) >/dev/null 2>&1
cd "$ghp" || exit 1
rm -f "$tmp/gh-calls"
check "a created repository has the branches a merge finished with deleted" "says 'merged branches are deleted on GitHub after a merge' ghrun just _repo-autodelete && grep -qx 'api -X PATCH repos/{owner}/{repo} -F delete_branch_on_merge=true' '$tmp/gh-calls'"
# The create path itself, under a terminal because that is where it asks; the
# settings call comes after the repository exists.
# import pty succeeds where openpty is refused (a seatbelt with no /dev/ptmx).
if "$py" -c 'import os; m, s = os.openpty(); os.close(m); os.close(s)' 2>/dev/null; then
  cat > "$tmp/ptyrun.py" <<'PY'
import os, pty, subprocess, sys
m, s = os.openpty()
p = subprocess.Popen(sys.argv[1:], stdin=s, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
os.close(s)
os.write(m, b"y\n")
out, _ = p.communicate()
sys.stdout.write(out)
sys.exit(p.returncode)
PY
  rm -f "$tmp/gh-calls"
  out=$(ghrun "$py" "$tmp/ptyrun.py" just publish 2>&1) && rc=0 || rc=$?
  check "publish creates the repo, then turns the setting on" "[ $rc -eq 0 ] && [ \"\$(git remote get-url origin)\" = '$tmp/gh-remote.git' ] && grep -qx 'repo create gh-proj --private --source=. --remote=origin' '$tmp/gh-calls' && grep -qx 'api -X PATCH repos/{owner}/{repo} -F delete_branch_on_merge=true' '$tmp/gh-calls'"
fi
cd "$tmp" || exit 1

fi
if lane_wants sweep; then
section "unwatched packages and the freshness sweep (n-058e8b)"
# A declared package with no [[watch]] row is a line. An allow row is not.
# A gitignored package.json is not a package the project holds (n-a65306).
# The behind line is the shared cache, so the sweep stays offline.
sw="$tmp/sweep-root"
rm -rf "$sw" "$tmp/sweep-cache" "$tmp/sweep-inst" "$tmp/sweep-home"
mkdir -p "$sw/alpha/docs" "$sw/alpha/.ai-backbone" "$sw/alpha/web/pkg" "$sw/beta/docs" "$sw/beta/.ai-backbone" "$tmp/sweep-cache"
printf '%s\n' 'web/' > "$sw/alpha/.gitignore"
printf '%s\n' '{"dependencies":{"left-pad":"1.0.0"},"devDependencies":{"typescript":"5.0.0"}}' > "$sw/alpha/package.json"
printf '%s\n' '{"dependencies":{"ignored-pkg":"1.0.0"}}' > "$sw/alpha/web/pkg/package.json"
cat > "$sw/alpha/Cargo.toml" <<'EOF'
[workspace]
members = []

[workspace.dependencies]
serde = "1"
private-crate = { version = "0.1", package = "private-crate" }
renamed = { package = "serde", version = "1" }
EOF
cat > "$sw/alpha/pyproject.toml" <<'EOF'
[project]
name = "demo"
dependencies = ["requests>=2", "rich[box]>=13"]

[project.optional-dependencies]
dev = ["pytest>=8"]

[dependency-groups]
lint = ["ruff>=0.5"]
EOF
cat > "$sw/alpha/docs/upstream.toml" <<'EOF'
[[watch]]
name = "serde-lib"
source = "crates:serde"
pin = "1.0.0"

[[unwatched]]
name = "requests"
why = "left out on purpose"

[[unwatched]]
name = "pytest"
why = "a test runner, not how this project is built"
EOF
git -C "$sw/alpha" init -q
printf '%s\n' '# core' > "$sw/alpha/.ai-backbone/core.just"
printf '%s\n' '# core' > "$sw/beta/.ai-backbone/core.just"
cat > "$sw/beta/docs/upstream.toml" <<'EOF'
[[watch]]
name = "demo-crate"
source = "crates:demo-crate"
pin = "1.0.0"
EOF
"$py" - "$tmp/sweep-cache" <<'PY'
import datetime, hashlib, json, re, sys
from pathlib import Path
key = "crates:demo-crate"
slug = re.sub(r"[^A-Za-z0-9._+-]+", "_", key).strip("_")
digest = hashlib.sha256(key.encode()).hexdigest()[:12]
when = datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat()
record = {"source": key, "fetched": when, "releases": [
    {"version": "2.0.0", "at": "2026-11-01", "url": "", "notes": "", "prerelease": False}],
    "error": "", "detail": "", "failed_at": ""}
Path(sys.argv[1], f"{slug}--{digest}.json").write_text(json.dumps(record), encoding="utf-8")
PY
# The last grep must not be the function's status: a name that is absent is
# what we want, and grep then exits 1 (n-058e8b).
nw_has() {
  local name
  for name in left-pad private-crate rich ruff typescript; do
    grep -qx "not watched: $name" "$1" || return 1
  done
  for name in requests pytest serde ignored-pkg serde-lib; do
    if grep -qx "not watched: $name" "$1"; then return 1; fi
  done
  return 0
}
( cd "$sw/alpha" && "$py" "$root/.ai-backbone/upstream.py" --freshness >"$tmp/nw-fresh.out" 2>&1 ) || true
check "freshness names each unwatched package and skips a watch, an allow row and a gitignored package" "nw_has '$tmp/nw-fresh.out' && grep -q '=== FRESHNESS' '$tmp/nw-fresh.out'"
( cd "$sw/alpha" && "$py" "$root/.ai-backbone/upstream.py" >"$tmp/nw-up.out" 2>&1 ) || true
check "just upstream names the same unwatched packages" "nw_has '$tmp/nw-up.out'"
env AI_BACKBONE_PROJECTS="$sw" AI_BACKBONE_FRESHNESS_FILE="$tmp/sweep-list.txt" AI_BACKBONE_UPSTREAM_CACHE="$(winpath "$tmp/sweep-cache")" \
  just -f "$root/Justfile" -d "$root" freshness-sweep >"$tmp/sweep-run.txt" 2>&1 || true
# Git Bash may spell the same file as C:/... or /c/... after just.exe (spec 020).
# A silent grep used to fail with the previous command's text still in $out.
sweep_ok() {
  local line path want
  want=$tmp/sweep-list.txt
  line=$(grep '^Wrote ' "$tmp/sweep-run.txt" 2>/dev/null || true)
  line=${line%%$'\n'*}
  line=${line%$'\r'}
  path=${line#Wrote }
  path=${path%$'\r'}
  if [ "$path" != "$want" ]; then
    if [ -z "$path" ] || [ ! -f "$want" ] || [ ! -f "$path" ] || [ ! "$path" -ef "$want" ]; then
      printf '%s\n' "wrote: ${line:-<none>}" "wanted: $want" "---- run ----"
      cat "$tmp/sweep-run.txt" 2>/dev/null || true
      return 1
    fi
  fi
  if [ ! -f "$want" ]; then printf '%s\n' "no list"; return 1; fi
  grep -qx '== alpha ==' "$want" || { printf '%s\n' "no alpha"; cat "$want"; return 1; }
  grep -qx '== beta ==' "$want" || { printf '%s\n' "no beta"; cat "$want"; return 1; }
  grep -qx 'not watched: left-pad' "$want" || { printf '%s\n' "no left-pad"; cat "$want"; return 1; }
  grep -qx 'not watched: typescript' "$want" || { printf '%s\n' "no typescript"; cat "$want"; return 1; }
  grep -qxF 'Behind: demo-crate 1.0.0 → 2.0.0' "$want" || { printf '%s\n' "no behind"; cat "$want"; return 1; }
  if grep -qx 'not watched: requests' "$want"; then printf '%s\n' "requests was listed"; return 1; fi
  if grep -qx 'not watched: ignored-pkg' "$want"; then printf '%s\n' "ignored-pkg was listed"; return 1; fi
  return 0
}
check "the sweep writes one behind line and the unwatched lines, per project" sweep_ok
mkdir -p "$tmp/sweep-inst/.ai-backbone" "$tmp/sweep-home/Library/LaunchAgents" "$tmp/sweep-sched"
cp "$root/.ai-backbone/freshness-sweep.sh" "$tmp/sweep-inst/.ai-backbone/"
git -C "$tmp/sweep-inst" init -q
git -C "$tmp/sweep-inst" config user.email "sweep@example.com"
git -C "$tmp/sweep-inst" config user.name "Sweep"
# Same import as the map tests: just on Windows cannot open a Git Bash path (spec 020).
printf "import? '%s/.ai-backbone/core.just'\n" "$rootw" > "$tmp/sweep-inst/Justfile"
# Scheduler stand-ins. The real launchctl, systemctl, crontab and schtasks
# are never called: a test that loaded them would touch this machine.
sweep_fakes() {
  local d=$1 uname_text=$2 sys_rc=$3 cron_rc=$4
  mkdir -p "$d"
  cat > "$d/launchctl" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "${SWEEP_SCHED_LOG:?}"
exit 0
EOF
  cat > "$d/schtasks" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "${SWEEP_SCHED_LOG:?}"
exit 0
EOF
  cat > "$d/systemctl" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >> "\${SWEEP_SCHED_LOG:?}"
exit $sys_rc
EOF
  cat > "$d/crontab" <<EOF
#!/bin/sh
store="\${SWEEP_CRON_STORE:?}"
if [ "\$1" = "-l" ]; then
  [ -f "\$store" ] || exit 1
  cat "\$store"
  exit 0
fi
cp "\$1" "\$store"
exit $cron_rc
EOF
  if [ -n "$uname_text" ]; then printf '#!/bin/sh\necho %s\n' "$uname_text" > "$d/uname"; fi
  chmod +x "$d"/*
}
sweep_fakes "$tmp/sweep-sched" "" 0 0
export SWEEP_SCHED_LOG="$tmp/sweep-sched.log" SWEEP_CRON_STORE="$tmp/sweep-cron.txt"
: > "$SWEEP_SCHED_LOG"
rm -f "$SWEEP_CRON_STORE"
sweep_installed() {
  case "$(uname)" in
    Darwin)
      local p="$1/Library/LaunchAgents/ai-backbone.freshness-sweep.plist"
      grep -q '<integer>8</integer>' "$p" && grep -q '<integer>15</integer>' "$p" && grep -q 'freshness-sweep.sh' "$p"
      ;;
    Linux)
      local timer="$1/.config/systemd/user/ai-backbone-freshness-sweep.timer"
      local svc="$1/.config/systemd/user/ai-backbone-freshness-sweep.service"
      grep -qF 'OnCalendar=*-*-* 08:15:00' "$timer" && grep -q 'freshness-sweep.sh' "$svc" && [ ! -e "$1/Library/LaunchAgents/ai-backbone.freshness-sweep.plist" ]
      ;;
    MINGW*|MSYS*|CYGWIN*|Windows_NT)
      local marker="$1/AppData/Local/ai-backbone/ai-backbone-freshness-sweep.task"
      grep -q '08:15' "$marker" && grep -q 'DAILY' "$2" && grep -q '08:15' "$2" && [ ! -e "$1/Library/LaunchAgents/ai-backbone.freshness-sweep.plist" ]
      ;;
    *)
      return 1
      ;;
  esac
}
( cd "$tmp/sweep-inst" && env -u XDG_CONFIG_HOME -u XDG_DATA_HOME -u LOCALAPPDATA HOME="$tmp/sweep-home" PATH="$tmp/sweep-sched:$PATH" AI_BACKBONE_FRESHNESS_FILE="$tmp/sweep-list.txt" just freshness-sweep-install >"$tmp/sweep-inst.out" 2>&1 ) || true
check "the installer writes the daily job, marks this checkout the desk, and does not touch the real home" \
  "grep -q 'This checkout is the desk' '$tmp/sweep-inst.out' && [ \"\$(git -C '$tmp/sweep-inst' config --local --get ai-backbone.desk)\" = true ] && sweep_installed '$tmp/sweep-home' '$tmp/sweep-sched.log' && [ ! -e \"$HOME/Library/LaunchAgents/ai-backbone.freshness-sweep.plist\" ] && [ ! -e \"$HOME/.config/systemd/user/ai-backbone-freshness-sweep.timer\" ] && [ ! -e \"$HOME/.local/share/ai-backbone/freshness-sweep.sh\" ]"
# The same install, with uname forced, so a Mac run proves the Linux and
# Windows jobs and a Linux run proves it never writes a launchd plist.
sweep_as() {
  local name=$1 uname_text=$2 sys_rc=$3 cron_rc=$4
  local home="$tmp/sweep-$name-home" bin="$tmp/sweep-$name-bin" log="$tmp/sweep-$name.log" store="$tmp/sweep-$name.cron" out="$tmp/sweep-$name.out"
  rm -rf "$home" "$bin"
  mkdir -p "$home/Library/LaunchAgents"
  sweep_fakes "$bin" "$uname_text" "$sys_rc" "$cron_rc"
  : > "$log"
  rm -f "$store"
  (
    cd "$tmp/sweep-inst" && env -u XDG_CONFIG_HOME -u XDG_DATA_HOME -u LOCALAPPDATA \
      HOME="$home" PATH="$bin:$PATH" SWEEP_SCHED_LOG="$log" SWEEP_CRON_STORE="$store" \
      AI_BACKBONE_FRESHNESS_FILE="$tmp/sweep-list.txt" \
      just freshness-sweep-install >"$out" 2>&1
  ) || { echo "install $name exited $?"; cat "$out"; return 1; }
  SWEEP_AS_HOME=$home SWEEP_AS_LOG=$log SWEEP_AS_STORE=$store SWEEP_AS_OUT=$out SWEEP_AS_BIN=$bin
}
sweep_linux() {
  sweep_as linux Linux 0 0 || return 1
  local home=$SWEEP_AS_HOME timer="$SWEEP_AS_HOME/.config/systemd/user/ai-backbone-freshness-sweep.timer" svc="$SWEEP_AS_HOME/.config/systemd/user/ai-backbone-freshness-sweep.service"
  grep -q 'Schedule: systemd user timer' "$SWEEP_AS_OUT" || { echo "no systemd line"; cat "$SWEEP_AS_OUT"; return 1; }
  grep -q 'This checkout is the desk' "$SWEEP_AS_OUT" || return 1
  grep -qF 'OnCalendar=*-*-* 08:15:00' "$timer" || { echo "timer"; cat "$timer"; return 1; }
  grep -q 'freshness-sweep.sh' "$svc" || { echo "service"; return 1; }
  [ ! -e "$home/Library/LaunchAgents/ai-backbone.freshness-sweep.plist" ] || { echo "launchd plist on linux"; return 1; }
  [ ! -e "$SWEEP_AS_STORE" ] || { echo "cron beside systemd"; return 1; }
  if grep -q 'bootstrap' "$SWEEP_AS_LOG"; then echo "launchctl ran"; cat "$SWEEP_AS_LOG"; return 1; fi
  if grep -q 'bootout' "$SWEEP_AS_LOG"; then echo "launchctl ran"; cat "$SWEEP_AS_LOG"; return 1; fi
  ( cd "$tmp/sweep-inst" && env -u XDG_CONFIG_HOME -u XDG_DATA_HOME HOME="$home" PATH="$SWEEP_AS_BIN:$PATH" SWEEP_SCHED_LOG="$SWEEP_AS_LOG" SWEEP_CRON_STORE="$SWEEP_AS_STORE" just freshness-sweep-remove >"$tmp/sweep-linux-rm.out" 2>&1 ) || { echo "remove exited $?"; return 1; }
  grep -q '^Removed' "$tmp/sweep-linux-rm.out" || { echo "not removed"; cat "$tmp/sweep-linux-rm.out"; return 1; }
  [ ! -e "$timer" ] || { echo "timer remains"; return 1; }
}
sweep_cron() {
  sweep_as cron Linux 1 0 || return 1
  local home=$SWEEP_AS_HOME
  grep -q 'Schedule: cron' "$SWEEP_AS_OUT" || { echo "no cron line"; cat "$SWEEP_AS_OUT"; return 1; }
  grep -q '15 8' "$SWEEP_AS_STORE" || { echo "crontab"; cat "$SWEEP_AS_STORE"; return 1; }
  grep -q 'freshness-sweep.sh' "$SWEEP_AS_STORE" || return 1
  grep -q 'ai-backbone-freshness-sweep' "$SWEEP_AS_STORE" || return 1
  [ ! -e "$home/.config/systemd/user/ai-backbone-freshness-sweep.timer" ] || { echo "timer beside cron"; return 1; }
  [ ! -e "$home/Library/LaunchAgents/ai-backbone.freshness-sweep.plist" ] || { echo "launchd plist on cron"; return 1; }
  [ -f "$home/.config/ai-backbone/freshness.cron" ] || { echo "cron file missing"; return 1; }
  ( cd "$tmp/sweep-inst" && env -u XDG_CONFIG_HOME -u XDG_DATA_HOME HOME="$home" PATH="$SWEEP_AS_BIN:$PATH" SWEEP_SCHED_LOG="$SWEEP_AS_LOG" SWEEP_CRON_STORE="$SWEEP_AS_STORE" just freshness-sweep-remove >"$tmp/sweep-cron-rm.out" 2>&1 ) || return 1
  grep -q '^Removed' "$tmp/sweep-cron-rm.out" || { echo "cron not removed"; cat "$tmp/sweep-cron-rm.out"; return 1; }
  [ ! -e "$home/.config/ai-backbone/freshness.cron" ] || { echo "cron file remains"; return 1; }
  if grep -q 'ai-backbone-freshness-sweep' "$SWEEP_AS_STORE"; then echo "crontab line remains"; cat "$SWEEP_AS_STORE"; return 1; fi
}
sweep_windows() {
  sweep_as win MINGW64_NT-10.0 0 0 || return 1
  local home=$SWEEP_AS_HOME marker="$SWEEP_AS_HOME/AppData/Local/ai-backbone/ai-backbone-freshness-sweep.task"
  grep -q 'Schedule: Task Scheduler' "$SWEEP_AS_OUT" || { echo "no task line"; cat "$SWEEP_AS_OUT"; return 1; }
  grep -q '08:15' "$marker" || { echo "marker"; cat "$marker"; return 1; }
  grep -q 'DAILY' "$SWEEP_AS_LOG" || { echo "schtasks"; cat "$SWEEP_AS_LOG"; return 1; }
  grep -q '08:15' "$SWEEP_AS_LOG" || return 1
  grep -q 'ai-backbone-freshness-sweep' "$SWEEP_AS_LOG" || return 1
  [ ! -e "$home/Library/LaunchAgents/ai-backbone.freshness-sweep.plist" ] || { echo "launchd plist on windows"; return 1; }
  ( cd "$tmp/sweep-inst" && env -u XDG_CONFIG_HOME -u XDG_DATA_HOME -u LOCALAPPDATA HOME="$home" PATH="$SWEEP_AS_BIN:$PATH" SWEEP_SCHED_LOG="$SWEEP_AS_LOG" SWEEP_CRON_STORE="$SWEEP_AS_STORE" just freshness-sweep-remove >"$tmp/sweep-win-rm.out" 2>&1 ) || return 1
  grep -q '^Removed' "$tmp/sweep-win-rm.out" || { echo "task not removed"; cat "$tmp/sweep-win-rm.out"; return 1; }
  [ ! -e "$marker" ] || { echo "marker remains"; return 1; }
}
sweep_unsupported() {
  git -C "$tmp/sweep-inst" config --local --unset ai-backbone.desk || true
  sweep_as none Linux 1 1 || return 1
  grep -q 'not supported here' "$SWEEP_AS_OUT" || { echo "no unsupported line"; cat "$SWEEP_AS_OUT"; return 1; }
  grep -q 'This checkout is the desk' "$SWEEP_AS_OUT" || return 1
  [ "$(git -C "$tmp/sweep-inst" config --local --get ai-backbone.desk)" = true ] || { echo "desk not marked"; return 1; }
  [ ! -e "$SWEEP_AS_HOME/.config/systemd/user/ai-backbone-freshness-sweep.timer" ] || return 1
  [ ! -e "$SWEEP_AS_HOME/.config/ai-backbone/freshness.cron" ] || return 1
  [ ! -e "$SWEEP_AS_HOME/Library/LaunchAgents/ai-backbone.freshness-sweep.plist" ] || return 1
}
check "on linux the sweep installs a systemd user timer at 08:15 and no launchd job" "sweep_linux"
check "without a systemd user timer, linux installs cron at 08:15" "sweep_cron"
check "on windows the sweep schedules 08:15 with Task Scheduler and no launchd job" "sweep_windows"
check "with no scheduler the sweep says not supported here and still marks the desk" "sweep_unsupported"
printf '%s\n' '== beta ==' 'Behind: demo-crate 1.0.0 → 2.0.0' > "$tmp/sweep-list.txt"
( cd "$tmp/sweep-inst" && env -u XDG_CONFIG_HOME -u XDG_DATA_HOME HOME="$tmp/sweep-home" AI_BACKBONE_FRESHNESS_FILE="$tmp/sweep-list.txt" just session-start >"$tmp/sweep-desk.out" 2>&1 ) || true
check "the desk's session-start prints the sweep list" "grep -q '=== FRESHNESS SWEEP ===' '$tmp/sweep-desk.out' && grep -qF 'Behind: demo-crate 1.0.0 → 2.0.0' '$tmp/sweep-desk.out'"
( cd "$tmp/sweep-inst" && env -u XDG_CONFIG_HOME -u XDG_DATA_HOME -u LOCALAPPDATA HOME="$tmp/sweep-home" PATH="$tmp/sweep-sched:$PATH" just freshness-sweep-remove >"$tmp/sweep-rm.out" 2>&1 ) || true
check "removing the sweep takes the job and leaves the list" "[ ! -e '$tmp/sweep-home/Library/LaunchAgents/ai-backbone.freshness-sweep.plist' ] && [ ! -e '$tmp/sweep-home/.config/systemd/user/ai-backbone-freshness-sweep.timer' ] && [ ! -e '$tmp/sweep-home/.config/ai-backbone/freshness.cron' ] && [ ! -e '$tmp/sweep-home/AppData/Local/ai-backbone/ai-backbone-freshness-sweep.task' ] && grep -q '^Removed' '$tmp/sweep-rm.out' && [ -f '$tmp/sweep-list.txt' ]"
# The vault sweep uses the same Claude Code hooks, not launchd: a scheduled
# job cannot read the Desktop (n-a931f8). Install and remove leave every
# other hook, and the real home is not the one they write.
vault_support_dir() {
  local os=$1 home=$2
  case "$os" in
    Darwin) printf '%s/Library/Application Support/ai-backbone' "$home" ;;
    MINGW*|MSYS*|CYGWIN*|Windows_NT) printf '%s/AppData/Local/ai-backbone' "$home" ;;
    *) printf '%s/.local/share/ai-backbone' "$home" ;;
  esac
}
vault_seed_settings() {
  mkdir -p "$1/.claude"
  "$py" - "$1/.claude/settings.json" <<'PY'
import json, sys
data = {"hooks": {"Stop": [{"hooks": [{"type": "command", "command": "echo stranger-hook"}]}]}}
with open(sys.argv[1], "w", encoding="utf-8", newline="\n") as fh:
    json.dump(data, fh, indent=2, ensure_ascii=False)
    fh.write("\n")
PY
}
vault_install_case() {
  local name=$1 os=$2
  local home="$tmp/vault-home-$name" bin="$tmp/vault-bin-$name" settings script support host
  rm -rf "$home" "$bin"
  mkdir -p "$bin"
  vault_seed_settings "$home"
  cp "$home/.claude/settings.json" "$tmp/vault-seed-$name.json"
  if [ -n "$os" ]; then printf '#!/bin/sh\necho %s\n' "$os" > "$bin/uname"; chmod +x "$bin/uname"; host=$os; else host=$(uname); fi
  support=$(vault_support_dir "$host" "$home")
  script="$support/vault-sweep.sh"
  settings="$home/.claude/settings.json"
  (
    cd "$root" && env -u XDG_DATA_HOME -u XDG_CONFIG_HOME -u LOCALAPPDATA \
      HOME="$home" PATH="$bin:$PATH" \
      just vault-sweep-install >"$tmp/vault-out-$name.txt" 2>&1
  ) || { echo "install $name failed"; cat "$tmp/vault-out-$name.txt"; return 1; }
  grep -q 'at most once every 3 hours' "$tmp/vault-out-$name.txt" || { cat "$tmp/vault-out-$name.txt"; return 1; }
  [ -f "$script" ] && [ -x "$script" ] || { echo "script missing: $script"; return 1; }
  grep -q 'vault-sweep.sh' "$settings" && grep -q -- '--periodic' "$settings" || { echo "hook:"; cat "$settings"; return 1; }
  grep -q 'echo stranger-hook' "$settings" || return 1
  "$py" "$root/.ai-backbone/budget.py" sweep check "$settings" || { echo "sweep check failed"; cat "$settings"; return 1; }
  [ ! -e "$home/Library/LaunchAgents/ai-backbone.vault-sweep.plist" ] || { echo "a launchd plist was written"; return 1; }
  cp "$settings" "$tmp/vault-after-$name.json"
  (
    cd "$root" && env -u XDG_DATA_HOME -u XDG_CONFIG_HOME -u LOCALAPPDATA \
      HOME="$home" PATH="$bin:$PATH" \
      just vault-sweep-install >"$tmp/vault-out-$name-2.txt" 2>&1
  ) || { echo "second install failed"; cat "$tmp/vault-out-$name-2.txt"; return 1; }
  grep -q 'already installed' "$tmp/vault-out-$name-2.txt" || { cat "$tmp/vault-out-$name-2.txt"; return 1; }
  cmp -s "$settings" "$tmp/vault-after-$name.json" || { echo "second install rewrote the settings"; return 1; }
  (
    cd "$root" && env -u XDG_DATA_HOME -u XDG_CONFIG_HOME -u LOCALAPPDATA \
      HOME="$home" PATH="$bin:$PATH" \
      just vault-sweep-remove >"$tmp/vault-rm-$name.txt" 2>&1
  ) || { echo "remove failed"; cat "$tmp/vault-rm-$name.txt"; return 1; }
  grep -q '^Removed' "$tmp/vault-rm-$name.txt" || { cat "$tmp/vault-rm-$name.txt"; return 1; }
  cmp -s "$settings" "$tmp/vault-seed-$name.json" || { echo "remove did not restore"; diff -u "$tmp/vault-seed-$name.json" "$settings"; return 1; }
  grep -q 'echo stranger-hook' "$settings" || return 1
  if grep -q 'vault-sweep.sh' "$settings"; then echo "the sweep hook stayed"; return 1; fi
  [ -f "$script" ] || { echo "remove deleted the script"; return 1; }
}
if [ -f "$HOME/.claude/settings.json" ]; then cp "$HOME/.claude/settings.json" "$tmp/vault-real-settings"; else : > "$tmp/vault-real-absent"; fi
check "vault-sweep-install and remove round-trip the user hooks and leave other hooks" "vault_install_case here ''"
check "on linux the vault sweep is a script under .local/share and not a launchd job" "vault_install_case linux Linux"
check "on windows the vault sweep is a script under AppData and not a launchd job" "vault_install_case win Windows_NT"
vault_real_home_ok() {
  if [ -f "$tmp/vault-real-absent" ]; then
    [ ! -f "$HOME/.claude/settings.json" ]
  else
    cmp -s "$tmp/vault-real-settings" "$HOME/.claude/settings.json"
  fi
}
check "the vault installer does not touch the real home" "vault_real_home_ok"

fi
if lane_wants audit; then
section "cargo-audit is the RustSec reader (n-2ed2cf)"
# The stand-in records the flags. A reasoned row is an ignore entry, and the
# scan still reports the finding so the gate can say the day passed.
rm -f "$tmp/audit-argv"
audit_py=$("$py" -c 'import importlib.util as i, sys; s = i.spec_from_file_location("u", sys.argv[1]); u = i.module_from_spec(s); s.loader.exec_module(u); print(u.audit_ignores({"RUSTSEC-2099-0001": {"why": "only tests build it", "fault": ""}, "RUSTSEC-2099-0002": {"why": "", "fault": "it has no why"}}))' "$root/.ai-backbone/upstream.py")
printf '%s\n' "$audit_py" > "$tmp/audit-ignores.txt"
check "a reasoned row is a cargo-audit ignore entry, and a row with no reason is not" "grep -qx 'id = \"RUSTSEC-2099-0001\"' '$tmp/audit-ignores.txt' && grep -qx 'reason = \"only tests build it\"' '$tmp/audit-ignores.txt' && grep -qx '\[\[advisories.ignore\]\]' '$tmp/audit-ignores.txt' && ! grep -q 'RUSTSEC-2099-0002' '$tmp/audit-ignores.txt'"
reg="registry+https://github.com/rust-lang/crates.io-index"
printf 'version = 4\n\n[[package]]\nname = "foo"\nversion = "1.2.0"\nsource = "%s"\n' "$reg" > "$tmp/audit.lock"
env AI_BACKBONE_CARGO_AUDIT_ARGV="$tmp/audit-argv" AI_BACKBONE_ADVISORY_DB="$(winpath "$tmp/s29-db")" \
  "$py" "$root/.ai-backbone/upstream.py" --advisories doctor "$(winpath "$tmp/audit.lock")" >"$tmp/audit-doc.out" 2>&1 || true
check "advisories runs cargo-audit with --json, the lock, the database and --no-fetch" "grep -q -- '--json' '$tmp/audit-argv' && grep -q -- '--no-fetch' '$tmp/audit-argv' && grep -q -- '--file' '$tmp/audit-argv' && grep -q -- '--db' '$tmp/audit-argv' && grep -q 'RUSTSEC-2099-0001' '$tmp/audit-doc.out'"
# The shape of the Windows launch, on every machine. CreateProcess (shell=False)
# will not start a .cmd or a shebang script; an .exe still runs as itself (spec 020).
cat > "$tmp/audit-win.py" << 'PY'
import importlib.util, os, sys
from pathlib import Path
path, tmp = sys.argv[1], sys.argv[2]
spec = importlib.util.spec_from_file_location("u", path)
u = importlib.util.module_from_spec(spec)
spec.loader.exec_module(u)
env = {"ComSpec": r"C:\Windows\System32\cmd.exe", "SystemRoot": r"C:\Windows"}
cmd = u.cargo_audit_windows_argv([r"C:\tools\cargo-audit.cmd", "--json", "--file", "L"], env)
expect = [r"C:\Windows\System32\cmd.exe", "/d", "/c", r"C:\tools\cargo-audit.cmd", "--json", "--file", "L"]
if cmd != expect:
    sys.exit("cmd " + repr(cmd))
upper = u.cargo_audit_windows_argv([r"C:\tools\cargo-audit.CMD", "--json"], env)
if upper[:4] != [r"C:\Windows\System32\cmd.exe", "/d", "/c", r"C:\tools\cargo-audit.CMD"]:
    sys.exit("upper " + repr(upper))
exe = u.cargo_audit_windows_argv([r"C:\tools\cargo-audit.exe", "--json"], env)
if exe != [r"C:\tools\cargo-audit.exe", "--json"]:
    sys.exit("exe " + repr(exe))
bare = u.cargo_audit_windows_argv([r"C:\tools\cargo-audit.BAT", "--version"], {"SystemRoot": r"C:\Windows"})
com = os.path.join(r"C:\Windows", "System32", "cmd.exe")
if bare != [com, "/d", "/c", r"C:\tools\cargo-audit.BAT", "--version"]:
    sys.exit("bat " + repr(bare))
script = Path(tmp) / "cargo-audit-shebang"
script.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8", newline="\n")
got = u.cargo_audit_windows_argv([str(script), "--json"], env)
interp = got[0].replace("\\", "/").lower()
if not interp.endswith("/sh") and not interp.endswith("/sh.exe"):
    sys.exit("interp " + repr(got))
if got[1:] != [str(script), "--json"]:
    sys.exit("shebang " + repr(got))
if os.name != "nt" and u.cargo_audit_argv(["cargo-audit", "--json"]) != ["cargo-audit", "--json"]:
    sys.exit("posix argv changed")
PY
check "Windows runs cargo-audit.cmd through cmd, a script through its interpreter, and cargo-audit.exe as itself" \
  "\"\$py\" \"$tmp/audit-win.py\" \"$root/.ai-backbone/upstream.py\" \"$tmp\""

fi
sec_times="$sec_times$((SECONDS-sec_start)) $sec_name"$'\n'
echo
echo "== time by section, slowest first (${SECONDS}s in all) =="
printf '%s' "$sec_times" | sort -rn | head -8 | awk '{ t = $1; $1 = ""; printf "  %4ds %s\n", t, substr($0, 2) }'
echo
echo "$pass ok, $fail failed"
[ "$fail" -eq 0 ]
