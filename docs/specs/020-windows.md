---
status: approved
date: 2026-09-24
---

# 020 — Windows green

## What

The backbone and the projects built on it work on a Windows machine under Git
Bash, the shell Claude Code itself uses there: `setup.sh`, the recipes, the
session hooks and the skills. The gate's Windows job goes from report-only to
deciding, like Linux and macOS, once its suite is green.

## Why

The maintainer met errors running Claude Code in this repository on Windows.
The gate's Windows job (run 35984108702, windows-2025, Git 2.55, Git Bash) runs
`setup.sh` and every tool fine, but about 220 of the suite's checks are red and
it is cut at eight minutes. Read from that log and the code, the causes are few
and most of the red is their echo:

- **Line endings.** Git for Windows checks text out with CRLF
  (`core.autocrlf`): `AGENTS.md at most 7000 bytes (got 7122)` is 6980 bytes
  plus one byte per line, and `LF will be replaced by CRLF` fills the log.
- **Python's console encoding.** Python on Windows writes to a pipe in cp1252:
  `UnicodeEncodeError: 'charmap' codec can't encode character '\u0131'` (the
  Turkish ı). The session line comes from `budget.py`; on Windows it crashes
  and the session says "python3 is missing".
- **Symbolic links.** `.claude/skills/*` are links into `.agents/skills/`. With
  `core.symlinks` off (Git for Windows' default) they check out as small text
  files, so Claude Code sees no project skills; `ln -s` in Git Bash copies.
- **Tools a Mac and Linux have and Git Bash lacks or bends:** `shasum`, `zip`,
  `ps -o`, `/tmp` against `C:/Users/.../Temp` paths.
- **Silence.** The SessionStart hook ends in `2>/dev/null || true`, so none of
  this is seen from inside Claude Code.

Doing nothing leaves every Windows user with a backbone that half works and
says nothing about it.

## Not doing

- PowerShell or cmd as the shell. Git Bash is what Claude Code needs on
  Windows anyway; the docs say so.
- WSL: it is a Linux, and Linux is green.
- Changing what a person types.

## Questions

## Acceptance

- [x] The repository checks out with LF on Windows (`.gitattributes`), and so does every new project.
- [x] Every Python the recipes run writes UTF-8 and LF whatever the console's code page.
- [x] A failing `new-project` in the suite shows why, so the next run is read, not guessed.
- [x] Claude Code on Windows sees the project's skills without developer mode (copies, not links; measured on the gate, not yet in Claude Code itself).
- [x] The suite ends inside its cap on `windows-latest`, and green (run 36010227211: 522 ok, 0 failed, 15 minutes).
- [ ] `checks.yml` makes Windows a deciding machine; `promote.yml` and `gate.sh` judge it.
- [ ] A session on a real Windows machine with Claude Code, attended, shows the session line and the skills.

## Tasks

- [x] Step 1: `* text=auto eol=lf` in `.gitattributes`, `PYTHONUTF8=1` for the recipes, the suite shows why `new-project` failed. Measured: 220 red to 205 (3.27.3).
- [x] Step 2: what stays red, section by section, from the next log. Measured: 205 to 30 (3.27.4), 30 to 3 before the cap (3.27.5).
- [x] Step 3: the skills without symlinks on Windows (3.27.4).
- [x] Step 4: the last red checks, and the suite inside its cap (3.27.7 to 3.27.10, then 829f3a6).
- [ ] Step 5: Windows decides.
