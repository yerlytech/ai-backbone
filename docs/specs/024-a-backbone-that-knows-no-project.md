---
status: done
date: 2026-09-30
---

# 024 — A backbone that knows no project

## What

The backbone is public, so it carries nothing of the projects built on it:
not their names, not their ideas, not their plans — in the files, in the
backlog, and in the history. After this spec:

- **A note names no project** (the maintainer's word, 2026-09-30).
  `just backbone-note` writes
  `- [ ] DATE, n-XXXXXX: text`: a short id in place of the project's name. The
  sender keeps the pairing in its own `brain/notes-to-backbone.md`, and its
  `just session-start` reads the state of its notes (open, done) by id. A
  note that names the sender, or any project next to it on the machine
  (folder name or the name in its `AGENTS.md`), is refused before anything is
  written, like a path into `brain/`, an e-mail or a home folder today. A
  note that names no recipe and no file of the backbone is refused too: "say
  which recipe or file of the backbone this is about" (the maintainer's word,
  2026-09-30).
- **The backlog holds open lines only** (the maintainer's word, 2026-09-30).
  A line built is removed when the
  version that built it is published; the CHANGELOG entry is the record. The
  90 done lines of today go; the 12 open ones are kept, reworded to what the
  backbone should do, or set aside: the Windows session and the code-map
  comparison are the maintainer's own, with no urgency, and leave the public
  file.
- **The tree names no project.** The CHANGELOG, the comments in `core.just`
  and the suite, the fixtures, the specs and the radar's markers say "a
  project", "a Flutter project", "the first Rust project" where they named
  one. The suite's throwaway projects get made-up names. The maker's name in
  `LICENSE` stays: it names who made the backbone, not a project built on it.
- **The history is one commit again**, for the third time (3.0.0, 3.27.2;
  the maintainer's word, 2026-09-30):
  every one of the 68 commits since the last squash names a project in some
  file. The tags before it go with the history, as they did before; the
  CHANGELOG keeps every version's entry. This step runs on the maintainer's
  Mac, the one machine that can move tags on GitHub.
- **It stays that way.** A hook in the backbone's own checks refuses a commit
  (its diff, its file names, its message) that names a project next to it on
  the machine — the folders and their `AGENTS.md` rows, and a private
  `brain/private-names.txt` when the clone keeps one: the hook learns the
  names where they live and carries none of them — and the suite refuses a
  backlog line with a project's name in place of an id. Where no project sits
  next to the backbone (the gate's runners, a cloud session's sandbox) both
  have nothing to learn and refuse nothing: there the routine's brief and the
  skills are the rule, in one sentence, and the maintainer's machine is where
  a name is caught. A respelling that keeps the letters (`BlueKite`,
  `blue_kite`) is caught; the backbone's own GitHub address is never a name; a look-alike letter from another alphabet is not.

## Why

The maintainer said it on 2026-09-30: nobody should see a project's ideas or
notes in the backbone, not in its past either, and the backbone should not
depend on the projects. Measured the same day: `docs/backlog.md` names a
project on 49 of 102 lines (57 lines are the backbone's own), 90 of them done
and kept as a diary; the CHANGELOG names one in 11 places, `core.just` in 14
comments, the suite in 30 lines (its throwaway projects are named after real
ones), nine specs in passing, and every commit of the public history holds at
least one of these. Yesterday's rewrite (spec 023) took four fragments out of
the past; a name on every line and in every commit cannot be taken out that
way, only by a clean start. The routine never needs a project's name: it
builds what a line asks of the backbone.

## Not doing

- Making the repository private: the maintainer chose public at 3.27.2, and a
  public backbone that carries nothing of the projects is the point.
- Hiding the maker: `LICENSE` and the git author stay the maker's.
- Purging GitHub's caches: after the force push the old commits can still be
  reached by their hash for a while, until GitHub drops unreachable objects;
  only a request to GitHub support purges them sooner. Said to the maintainer,
  their call.
- Touching the projects: their `brain/notes-to-backbone.md` is written by the
  new recipe from then on; nothing is migrated.
- The Windows session (backlog 2026-09-24) and the code-map comparison
  (2026-09-28): set aside, dated, in the maintainer's journal in the
  backbone's `brain/` (their word, 2026-09-30), not built here.

## Questions

All five answered by the maintainer on 2026-09-30, each as proposed.


## Acceptance

- [x] `git grep` over the tracked files for the names of the projects on the
      maintainer's machine finds only `LICENSE`.
      *Checked on the maintainer's Mac in a fresh clone of 3df4f64, 2026-10-01:
      each name finds only `LICENSE` and the backbone's own GitHub address.*
- [x] `docs/backlog.md` holds open lines only, each `- [ ] DATE, n-XXXXXX: text`
      or `- [?] DATE, n-XXXXXX: …`, none naming a project; the routine builds from them as
      before (measured on a scratch run of the brief's step 5).
      *The suite checks the shape and scans every line with the note check;
      the routine built 3.31.2 from the list on 2026-10-01.*
- [x] `just backbone-note` writes an id, keeps the pairing in the sender's
      `brain/notes-to-backbone.md`, and the sender's `just session-start`
      says from it how many are still open, on their way, set aside by the
      hooks, or no longer listed (built).
      *Suite: the notes block, all four counts.*
- [x] A note that names the sender, a sibling project, or no recipe and no
      backbone file is refused with the reason, and nothing is written.
      *Suite: each refusal, Turkish letters and respellings included, with the
      outbox and the pairing file checked empty after.*
- [x] A commit in the backbone that names a project next to it on the machine
      is refused by the backbone's own hooks; the hook carries no name.
      *Suite: added lines, file names, renames and the message; the names come
      from the machine. The Mac's squash commit went through all 22 hooks.*
- [x] The suite refuses a backlog line that carries a name in the id's place.
      *Suite: the backlog shape check, broken once on purpose.*
- [x] The history on GitHub is one commit, tagged with the new version;
      `git log --all` in a fresh clone shows nothing older; the CHANGELOG
      says so in its header, as it does for 3.0.0 and 3.27.2.
      *2026-10-01, on the maintainer's Mac: orphan commit 3df4f64 (3.31.3),
      main and cloud force-pushed together, the 23 old tags deleted, `v3.31.3`
      the only tag; a fresh clone shows one line. Old commits stay fetchable
      by hash until GitHub's garbage collection; sooner needs GitHub support,
      the maintainer's call.*
- [x] The routine's brief, the backbone-dev and session skills, the
      getting-started page and how-it-works say the rule and the new line.
      *And, since 3.31.3, the second rule: a lesson keeps the lesson and drops
      the project.*
- [x] The Windows session and the code-map comparison are in the
      maintainer's journal and nowhere public.
      *brain/01-journal/2026-09-30.md, the set-aside list.*

## Tasks

- [x] The id, the private pairing and the sender's session-start line; the
      refusals (sender, siblings, no anchor); their checks and docs.
- [x] The backlog: open lines only, reworded; the two items set aside into
      the journal; the rule that the agent removes a built line before it
      publishes; the brief and the skills.
- [x] The tree scrub: CHANGELOG, `core.just` comments, the suite's names and
      fixtures, the specs, the radar; a suite check that the names are gone
      (fed from the machine, never from a list in the file).
- [x] The hook in the backbone's own `.pre-commit-config.yaml`, with its
      check.
- [x] Reviewed by three independent readers (privacy and leaks; correctness and portability; docs, brief and tests), each reproducing its findings; all fixed; twenty-two checks broken once on purpose, each turning its check red.
- [x] Published as one version (3.31.0 on main at b7dc564, the gate green on
      three machines, 2026-09-30; 3.31.1 after what the Mac found: the
      respelling example was two neighbours' names, and the hook read the
      owner in the backbone's own address as a name; 3.31.3 after its second,
      read-only sweep: the lesson stays, the project goes); then, on the
      maintainer's Mac: the squash, the force push, the tags; verified in a
      fresh clone. *Done 2026-10-01: 3df4f64, `v3.31.3`, one line in
      `git log --all`; the two sentences the sweep had still missed were
      generalized in that commit.*
