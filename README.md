# ai-backbone

The rules, commands and folders an AI coding agent works inside — in any
language, in any editor or agent that reads an `AGENTS.md` file (the plain
text file where a project tells its agents how to behave). You describe the
product; the agent builds it on top of this.

## What this is

A backbone, not a starter kit. A starter kit gives you one language and one
shape of project. A backbone gives you what every project needs regardless of
language: how work is saved and undone, how an idea becomes a one-page plan
before it becomes code, what is checked before anything is committed, where
private notes live, how the project keeps itself current, and how much of your
AI budget a session may spend. A game in Flutter, a service in Rust, an app in
Swift, or something in a language nobody has used with it yet: each gets the
same ground, and the agent working in it already knows the rules.

It is project-independent on purpose. The backbone is a folder that sits next
to your projects and stays there: new projects are made from it, language
layers are copied from it, updates come through it. Each project carries a
copy of the pieces it needs and takes new versions when it wants them; an
update replaces only the files the backbone owns and never yours.

## Who it is for

- **A developer** who would rather not set up tests, hooks, a secret scanner,
  a changelog and a release process again for every new idea, and who wants
  the agent held to a standard from the first commit.
- **A person with an idea and no engineering background**, who will run the
  project through an AI agent and needs the engineering discipline to be
  there without having to learn it. You type four commands; the agent runs
  the rest.

## What it does for you

- **Four commands.** `just save`, `just undo`, `just publish`, `just doctor`.
  Everything else the agent runs for you (`just --list` shows all of it).
- **A plan before code.** Anything bigger than a small fix starts as a
  one-page spec in `docs/specs/`. The agent asks you one question at a time;
  when you say *approved*, it builds.
- **Guards on every save.** Leaked passwords and keys, the wording of the
  save message, the language's linter once a language is chosen, files too
  big to belong: checked before a save lands, never after.
- **A private notebook.** `brain/`, in your own language, made when the
  project is created and never committed: git ignores it and a check refuses
  any save that includes it. Journals, research, chat archives. At the end of
  a session it is mirrored into one folder you name once — a second disk, a
  cloud-drive folder — so a lost laptop does not take it.
- **A project that stays current.** Every session says whether the backbone
  has a newer version (`just template-check`), and once the agent has started
  the watch list (`just upstream-init`), once a week what the things your
  project is built on have released (`just upstream`).
- **Work that goes on without you.** A project can run a scheduled agent
  once a week that finishes one task of an approved spec
  (`just routine-install`, on a Mac today). The backbone itself is developed
  that way: a daily cloud routine works on a branch, and a gate on GitHub
  runs the backbone's own test suite on a clean Linux and a clean Mac before
  a change reaches `main`, and on Windows as a report.

## What it is built on, and why

Six small tools, installed once by `sh .ai-backbone/setup.sh` (on a Mac it
installs Homebrew first; on Linux, git is installed by hand). You do not have
to learn them; the agent uses them for you, and `just doctor` says when one is
missing.

| Tool | What it is | Why it is here |
|---|---|---|
| **git** | the version history, and the way work reaches GitHub | every save is a point you can return to; every publish is a push |
| **just** | a command runner: `just save`, `just doctor` | one word per action, the same in every language, so the person types four commands and the agent types the rest |
| **prek** | runs the checks before every commit (a hook runner) | the guards run whether or not anybody remembers them; **gitleaks**, which it runs, stops a password from ever reaching GitHub |
| **graphify** | draws a map of the code | the agent reads the map instead of the whole codebase: fewer tokens, better answers |
| **uv** | installs Python tools into their own folder | the backbone's three small helpers (the tool watch, the Sunday look at what other agent tools published, the budget line) run without touching the system's Python or your project's language |
| **gh** | GitHub's command line | only for talking to GitHub: `just publish` creates a repository with it, `just ci` reads the checks. Saving and undoing never need it |

## What it costs

No API key. The agent runs on the subscription of the AI tool you already use;
this backbone adds no service, no server and no account of its own. A GitHub
account is needed for `just publish`.

Tokens are the real cost, and the backbone is built to spend fewer of them: an
agent reads the code map, not the whole codebase; rules are one file, read
once; a spec is one page. In Claude Code every session opens with one line
that says about how much of the week's limit is used, how many days until it
resets, and how many subagents may start without asking; past that number a
hook refuses the next subagent and the agent has to ask you. Subagents draw on
the same weekly limit as the session. In other tools the agent runs
`just session-start` itself and reads the same numbers; the cap is Claude
Code's for now.

## Start

1. **Get the folder, on your Desktop:**
   `git clone https://github.com/yerlytech/ai-backbone.git`. Download ZIP
   works too if you rename the unzipped folder from `ai-backbone-main` to
   `ai-backbone`: your projects find the backbone by that name, next to them,
   and it stays there.
2. **Open it in your AI tool.** Claude Code, Cursor, Codex, Gemini CLI, GitHub
   Copilot or Junie. The rules are in `AGENTS.md`; `CLAUDE.md` and `GEMINI.md`
   are one-line pointers to it. For Copilot or Junie, name the tool in section
   0 of `AGENTS.md` and the agent generates their full copy (`just sync-rules`).
3. **Say: "read AGENTS.md and set up this computer."** The agent runs the
   installer, tells you what it installed, and tells you when it is done.
4. **Say: "new project: my-app."** A ready folder appears next to this one.
   Pick a language then or later: Rust, Flutter and Swift have ready layers
   (`just stack rust`), and for any other language the agent writes the
   layer (`stack.just`) by hand.

macOS and Linux today. On Windows the tools install under Git Bash and the
backbone's own test suite runs, but about half of its checks are still red
(196 green, 223 red on 2026-09-24): Windows is being brought green, not
supported yet.

## What you see in a project

| | |
|---|---|
| `README.md` | what this project is |
| `AGENTS.md` | the rules every agent follows. Section 0 holds your language |
| `Justfile` | the commands. Type `just` to see the four you type yourself |
| `docs/` | the project's documentation, kept current by the agent |
| `src/` | the code |
| `brain/` | your private notebook. Never leaves this computer, except into the folder you named |

Everything else is plumbing: hidden folders and a few small files. The agent
uses them; you do not have to look at them. In VS Code the sidebar hides the
folders for you.

## The four commands

```
just save "what changed"    save your work on this machine
just undo                   throw away changes since the last save
just publish                send saved work to GitHub
just doctor                 what is missing on this machine
```

You can also just tell the agent "save". The first save takes longer: it
downloads the secret scanner once.

## Where the rest is

How the pieces fit together, in two pictures and no code:
[`docs/how-it-works.md`](docs/how-it-works.md). The full walkthrough, from the
installer to the scheduled agent, the gate and the budget line:
[`docs/01-getting-started.md`](docs/01-getting-started.md). Every version and
why: [`CHANGELOG.md`](CHANGELOG.md) — this is 3.27.2, and the history was
squashed to one commit on 2026-09-24 when the repository went public. Every
idea before it was built: [`docs/specs/`](docs/specs/).

Found a gap? Open an issue. Inside the backbone, work travels on the `cloud`
branch and the gate carries it to `main`. License: MIT.
