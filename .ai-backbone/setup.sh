#!/usr/bin/env bash
# Installs the tools this repo needs. Safe to run twice: it only adds what is
# missing. Run it as:  sh .ai-backbone/setup.sh        (add -y to skip the question)
#
#   git       saves and history            just      the command runner
#   uv        installs the two below        prek      checks every save for leaked secrets
#   graphify  the code map                  gh        talks to GitHub
#
# Where `just` comes from, because the two machines differ. On a Mac it is
# Homebrew's. On Linux it is `rust-just` from PyPI (`uv tool install rust-just`):
# a third party's repackaging of just, not the author's own release (its
# repository is github.com/gnpaone/rust-just; read on PyPI 2026-09-19, where it
# stood at 1.58.0, the author's newest). It is used on purpose: one installer
# fewer, and it arrives where just.systems is unreachable, a locked-down cloud
# sandbox for one. docs/upstream.toml watches github:casey/just, the author's
# releases, and nothing watches the package itself. A row for it would need a
# `pypi:` source kind, which upstream.py does not have, and it is not built:
# `just tools-update` moves the package, and the floor further down stops a
# just that is too old, wherever it came from.
#
# The exit code says one thing, for the caller that reads it (this repo's CI,
# an agent's first step): 0 when git, just (1.29.0 or newer), uv, prek and
# graphify are all on the PATH as the script ends, 1 when any of them is not,
# whichever step it was that could not put it there. `gh` is not counted: only
# `just publish` needs it, and on Linux it is installed by hand. The state of
# the repo itself — no vault, no hooks — is `just doctor`'s to report and never
# this script's exit code.
# Plain POSIX sh from here on: `sh setup.sh` must work where /bin/sh is dash
# (Debian, Ubuntu). `pipefail` is a bash option and stops dash at this line.
set -u
need() { command -v "$1" >/dev/null 2>&1; }
os=$(uname -s)

echo "This installs what is missing on this computer:"
echo "  git, just, uv, gh, prek, graphify$( [ "$os" = Darwin ] && echo ', and Homebrew if needed')"
if [ "${1:-}" != "-y" ]; then
  printf "Continue? [y/N] "; read -r a
  case "$a" in y|Y) ;; *) echo "Nothing installed."; exit 0 ;; esac
fi
echo

if [ "$os" = Darwin ]; then
  if ! need brew; then
    echo "-> Homebrew (the Mac's installer for command-line tools)"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv 2>/dev/null || true)"
  need git  || { echo "-> git";  xcode-select --install 2>/dev/null || brew install git; }
  need just || { echo "-> just"; brew install just; }
  need uv   || { echo "-> uv";   brew install uv; }
  need gh   || { echo "-> gh";   brew install gh; }
else
  need git  || echo "-> git is missing. Debian/Ubuntu: sudo apt install git"
  need uv   || { echo "-> uv";   curl -LsSf https://astral.sh/uv/install.sh | sh; }
  export PATH="$HOME/.local/bin:$PATH"
  # just comes through uv here: one installer fewer, and it works where
  # just.systems is unreachable (locked-down cloud sandboxes).
  # A sandbox drops a request now and then, so a refusal gets one more try.
  # Both attempts are live: what uv says is the only reason there is.
  need just || { echo "-> just"; uv tool install rust-just || uv tool install rust-just; }
  need gh   || echo "-> gh is missing (only needed for just publish). See https://cli.github.com"
fi

export PATH="$HOME/.local/bin:$PATH"
# The recipes need just 1.29.0 or newer (the [positional-arguments] attribute;
# the seed Justfile's `import?` needs 1.21.0). A distro package can be older —
# Ubuntu 24.04 ships 1.21.0 — and it stops at "unknown attribute" without saying
# why. Said here, before just reads a single recipe, and moved here too.
need_just=1.29.0
ver_ge() { [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -1)" = "$2" ]; }
have_just() { just --version 2>/dev/null | awk '{print $2}'; }
v=$(have_just)
if need just && ! ver_ge "$v" "$need_just"; then
  echo "-> just $v at $(command -v just) is older than $need_just, which the recipes need"
  if [ "$os" = Darwin ]; then brew upgrade just; else uv tool install rust-just || uv tool install rust-just; fi
  hash -r 2>/dev/null || true
  v=$(have_just)
  if ! ver_ge "$v" "$need_just"; then
    echo "just is still $v at $(command -v just); the recipes need $need_just or newer."
    echo "What the installer said above says why. Fix that and run this script again."
    exit 1
  fi
fi
need prek     || { echo "-> prek";     uv tool install prek      || uv tool install prek; }
need graphify || { echo "-> graphify"; uv tool install graphifyy || uv tool install graphifyy; }
uv tool update-shell >/dev/null 2>&1 || true

echo
# Every place an installer above puts `just` is on the PATH by now (brew's
# through `brew shellenv` above, uv's through the export), so a `just` that is
# missing here was not installed, and what the installer said is on the screen.
if need just; then
  just doctor
else
  echo "just is not on the PATH. What the installer said above, under '-> just', says why."
  echo "Fix that and run this script again; it only adds what is missing."
fi

# The one meaning of the exit code, decided here and written in the header, so
# that a caller is not left reading `just doctor`'s, which answers a different
# question. Written out rather than tallied along the way: what counts is what
# is on the PATH when the script ends, not which branch installed it.
gone=
for t in git just uv prek graphify; do need "$t" || gone="$gone $t"; done
if [ -n "$gone" ]; then
  echo
  echo "Still missing:$gone"
  echo "The '->' lines above carry what each installer said. That is the reason."
  exit 1
fi
exit 0
