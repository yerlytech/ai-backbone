---
status: approved
date: 2026-09-24
---

# 018 — A clean start for the public repository

## What

The repository went public on 2026-09-24 (spec 017). Three things make it
ready for a stranger: the maintainer's private vault leaves this machine and
its second copy; the git history becomes one commit, so a newcomer reads a
repository and not a diary; and the README says in plain words what this is,
who it is for, what it is built on and why, and what it costs in tokens.

## Why

The old history carries 200 commits of one person's project names, notes and
detours, and 51 version tags nobody outside needs; the vault here has served
its purpose (the maintainer works in the projects, the routine works in the
cloud); and the README was written for its owner, not for somebody who lands
on the page and asks "what is this, and is it for me?". `docs/backlog.md` line
61 asked for exactly this clean-up before the repository went public; it went
public first, so this is the clean-up after.

## How it works

- **The vault.** `brain/` here (5.9 MB: journals, research, the bundle of the
  history before 3.0.0) and its second copy under the iCloud folder go to the
  Trash, not to `rm`: reversible for a while, gone after. An empty vault is
  made again (`just brain-init`), because `just doctor` wants the folder and
  the session recipes write today's entry there; `brain/private-names.txt`
  (eight words the suite must not find in a lifted layer) is written again.
  The other projects' copies stay; the setting that makes copies is theirs
  too. The backbone's own copy will be the empty vault, a few kilobytes.
- **The history.** One commit, "feat: 3.27.2 — a clean start for the public
  repository", holding today's tree, force-pushed to `main` and to `cloud`;
  the 51 tags are deleted on GitHub and here, and the version's own tag is cut
  again on the new commit by the backstop. `CHANGELOG.md` stays whole as the
  record and its head says when the history was squashed, as it already says
  for 3.0.0. Consequences, each handled: the routine's lapse rule reads a
  spec's date from git, so for 14 days every approved spec looks freshly moved
  (its lines stay claimed; harmless); this Mac's clone is reset by hand; the
  projects copy files, not history, so they notice nothing; the cloud routine
  clones fresh every night. Nothing else on GitHub refers to a commit: no
  pull requests, no protection, and the runs of the day are read.
- **The README.** Rewritten in English for a newcomer: what this is (a
  project-independent backbone: the rules, commands and folders that make an
  AI agent useful from the first day, in any language, in any editor or agent
  that reads `AGENTS.md`), who it is for (a developer, or a person with an
  idea and no engineering background), what it does for you (the four
  commands, the spec-first loop, the private vault, the scheduled agent and
  the gate, the weekly tool watch), what it is built on and why (`git`,
  `just`, `prek` with `gitleaks`, `graphify`, `uv`: one table, one line
  each), the token budget (the first line of every session and the subagent
  cap), how to start (clone, or the ZIP with its folder renamed; the six agents it is used with),
  and where the rest is. Short paragraphs; nothing a person must learn to be
  well served.

## Not doing

- Erasing what is already public: the old commits exist in forks and caches
  nobody here controls; the fresh history is for newcomers, not a secret.
- Rewording the CHANGELOG, the specs or the backlog: they are the record.
- Turning off the second copies of the projects' vaults, or the setting.
- Translating the README: the code language of this repository is English;
  `AGENTS.md` section 0 is where a project picks its own.

## Questions

- The history rewrite cannot be undone and removes the 51 version tags and the
  bundle of the history before 3.0.0 (it lives only in the vault). I would
  answer yes: the CHANGELOG is the record of every version, projects pin the
  backbone by its number and never by a commit, and a newcomer gains a
  repository they can read in one sitting.

## Acceptance

- [x] `brain/` here holds only the empty vault, the journal template and
      `private-names.txt`; the iCloud copy of the backbone's vault is gone;
      `just doctor` finds nothing missing; `just self-test` is green.
- [x] Right after the squash `git rev-list --count origin/main` is 1,
      `origin/cloud` equals it, no tag but `v3.27.2` exists on GitHub, and it
      points at that commit.
- [x] `CHANGELOG.md` says when the history was squashed and why; `just
      session-start` in a project says "3.27.2" and `just template-update`
      takes it without a word about history.
- [x] The README answers, in this order, what this is, who it is for, what it
      does, what it is built on and why, what it costs, how to start; a reader
      who knows no tool meets no unexplained name; every command in it exists.
- [ ] The next unattended run clones the new history and ends normally.

## Tasks

- [x] The vault: to the Trash with its iCloud copy; `just brain-init`;
      `private-names.txt` again.
- [x] The README, and the CHANGELOG head line; version 3.27.2 on line 1 of
      `core.just`; `just save`.
- [x] The history: one commit from today's tree; force-push `main` and
      `cloud`; delete the tags on GitHub and here; the backstop tags v3.27.2;
      reset this clone; `just session-start` in a project.
- [ ] Walk Acceptance the morning after, with the routine's run.
