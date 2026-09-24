---
status: approved
date: 2026-09-24
---

# 017 — The cloud branch and the three-machine gate

## What

The backbone is developed away from the maintainer's machine. Everything an
unattended run or a cloud session pushes goes to the branch `cloud`, never to
`main`. A gate on GitHub tests every push to `cloud` on a clean Linux, a clean
Mac and a clean Windows machine; Linux and macOS decide, Windows only reports
until a spec of its own makes it green. What passes is carried to `main` as it
is (a fast-forward, never a merge made on a runner) and its version is tagged
in the same push. Projects keep taking `main`. The scheduled agent starts each
run from `cloud`, merges in the notes that reached `main`, and treats a red gate
as its first item, before the backlog. The stored routine prompt does not change.

## Why

Since 2026-09-14 the daily run has pushed straight to `main`, tested only by
its own sandbox (a Linux without the network the projects have), and the
maintainer's Mac was the machine that tagged the version. On 2026-09-24 the
maintainer decided the backbone must not depend on that Mac at all, and that
it must work on Linux, Windows and macOS. Nothing tests a macOS or Windows path
today. GitHub Actions is switched off on this repository; `docs/backlog.md`
line 62 asked whether to switch it on and was closed on 2026-09-23 as "will
decide when the time comes". This spec asks that decision and carries it out.
Without a gate, "developed in the cloud" means "untested on the machines it
runs on".

Facts this rests on (read 2026-09-24): `checks.yml` runs on pushes to `main`
and on pull requests, on `ubuntu-latest` only, and no run of it has ever
completed on GitHub (`gh run list` is empty; `actions/permissions` says
`enabled: false`); branch protection answers 403 on GitHub Free;
`_backbone-level` refuses a clone that is not on `main`; `backbone-note` from a
checkout with no branch pushes `HEAD:main`; `radar-save` measures against
`origin/main`; nothing stops the run editing `.github/workflows/`; this clone
has `ai-backbone.publish-on-save` set, so every save here is a push; `cloud`
exists on GitHub, identical to `main` at bda3351; every one of the last eleven
daily runs changed `core.just` line 1 and `CHANGELOG.md`, so a routine push is
almost never docs-only.

## How it works

- **`checks.yml`** runs on every push to `cloud` (pull requests dropped: nobody
  opens one here, and one would cost macOS minutes). A first job, `look`, runs
  `.ai-backbone/gate.sh look`: a tree diff between `main`'s tip and the pushed
  commit, which needs no history and so answers the same in a checkout of
  depth one (a merge-base test written for a full clone answered "docs-only"
  there for a push that carried code; reproduced 2026-09-24). The suite is
  skipped only when every file that differs is one of `docs/routine-log.md`,
  `docs/backlog.md`, `docs/radar.toml` or under `docs/specs/`. Everything else
  runs the suite, including the rest of `docs/`: the suite greps three of those
  pages, and `upstream.toml` is read by code. Judged against `main`'s tip,
  never against the previous push, so a commit whose run was cancelled cannot
  slip under a docs-only push. A fetch of `main` that fails means "run the
  suite". `look` always runs, so a run is never "all skipped". The suite runs on `ubuntu-latest`, `macos-latest`
  and `windows-latest`: `fail-fast: false`, Windows `continue-on-error`, every
  step under `shell: bash` (on Windows the default is PowerShell), a cap per
  machine (Windows 10 minutes until measured: its setup may run to the cap),
  `HOMEBREW_NO_AUTO_UPDATE=1`, the image name printed first. The concurrency
  block stays keyed on the commit, as `just ci-check` demands.
- **`promote.yml`** runs when `checks` completes for `cloud`. GitHub runs a
  `workflow_run` workflow from the default branch's copy, so the judge is
  `main`'s whatever `cloud` says: a push can change what is tested, never how
  it is judged. It checks out `main` with the whole history, sets a git
  identity (`github-actions[bot]`), grants itself `contents: write` and
  `actions: read`, is one queue of one (`group: promote`, never cancelled) and
  runs `main`'s `.ai-backbone/gate.sh carry`. The file contains the word "push"
  in no step: `gate.sh` does the pushing, and the ci-check hook keys any file
  that says "push" on the commit.
- **`gate.sh carry`** is a plain script so `just self-test` can try it against
  the suite's bare fixture repository on any machine, before a run exists. It
  reads the run's conclusion and tested commit from the event file and fetches
  that commit by name. In order: conclusion `cancelled` → superseded, write
  nothing; the tested commit is already on `main` → carried by an earlier
  promote, write nothing; conclusion not `success` → not carried; `main`'s own
  `look` says the suite was due but the run has no green suite job for Linux
  and macOS → not carried (a `look` weakened on `cloud` cannot smuggle code
  past the judge); `.github/workflows/` or `gate.sh` differs between `main` and
  the tested commit → not carried (such a change goes to `main` by a raw
  `git push` from an attended session after green checks; an unattended run
  puts `main`'s copy back); `main` cannot fast-forward → not carried, "main
  moved"; else read `version X.Y.Z` from line 1 of `core.just`, and when
  `git ls-remote --tags` shows no such tag, `git push --atomic origin main
  vX.Y.Z`: both refs or neither. A tag that exists elsewhere refuses the whole
  atomic push (reproduced), so then `main` is pushed alone and the line says the
  tag stood. Not carried: one line `- <date> gate: cloud not promoted — <why>`,
  naming the failing machine and up to five `FAIL` names from the deciding jobs
  only (the Windows job's are noise), appended to `docs/routine-log.md` on
  `cloud`, three tries from a fresh `origin/cloud`; refused three times, the
  verdict is in the run's log only. A push made with `GITHUB_TOKEN` starts no
  workflow, so neither the carry nor the verdict line runs the gate again, and
  the verdict commit rides the next real push.
- **The routine** (`.ai-backbone/routine.md`; the stored prompt untouched). The
  brief it reads is `main`'s, because the scheduler checks out the default
  branch; the tree it works is `cloud`'s. Step 4, before `just session-start`:
  unshallow if shallow, then `git fetch origin
  +refs/heads/cloud:refs/remotes/origin/cloud +refs/heads/main:refs/remotes/origin/main`
  (a shallow single-branch clone creates no `origin/cloud` from a plain fetch;
  reproduced), `git checkout --detach origin/cloud`, `git merge --no-edit
  origin/main` (a merge, never a rebase: a rebase would replay the notes as
  twins; only the `commit-msg` hook sees a merge and it accepts `Merge …`); a
  merge that stops is aborted and reported. Step 6 gets "the gate first": when
  `cloud` is ahead of `main` and the last `gate:` line explains it, that is the
  item — `main moved`: nothing, the merge did it; `.github/workflows` or
  `gate.sh`: put `main`'s copy back; `FAIL` names: reproduce with
  `just self-test` and fix; no `FAIL` names at all (a machine problem: setup,
  an image move, a fetch): push one empty commit so the gate runs again, and if
  that comes back the same, report and go on; cannot find the cause: revert,
  newest first, each non-merge commit ahead of `origin/main` that touches
  anything outside `docs/` (merges are never reverted; a revert that stops is
  aborted), reopen the backlog line those commits closed with the `FAIL` names
  and `blocked: the gate's <os> run says so`. Cloud ahead with no `gate:` line
  for it: not judged yet; take the backlog. Never force-push, never rewrite
  `cloud`. Step 12 pushes `HEAD:cloud`; refused, it fetches with the same
  refspecs, merges `origin/cloud`, runs the suite again when code came in, and
  pushes once more; it never tags. The Never list gains `.github/workflows/`
  and `.ai-backbone/gate.sh`.
- **Recipes.** `_backbone-level` takes a target: `main` for a clone on `main`
  (unchanged), `cloud` for a clone on `cloud` (pulled by merge); a checkout with
  no branch is up to date when it holds both `origin/main` and `origin/cloud`;
  it fetches `cloud` with an explicit refspec and tolerates its absence. Once
  the oldest non-merge commit on `cloud` and not on `main` is two days old (the
  tip is never old: the routine merges `main` daily), it says so in every
  session, projects included — the one way a stuck gate reaches a person's
  agent. From a project it also says when the sibling clone is on `cloud`, and
  `template-update` refuses to copy from a sibling that is not on `main`: what
  projects copy must be what the gate carried. The rails list gains
  `.github/workflows/` and `gate.sh`. `backbone-note` inside a `cloud` or
  no-branch checkout saves the note and lets it ride the run's push (today it
  pushes `HEAD:main`, which would carry untested commits); from a clone on
  `main`, notes travel on `main` as before. `publish`, and `save` with
  publish-on-save, refuse to push `main` from inside the backbone, name
  `git checkout -B cloud origin/cloud`, and say how commits already on local
  `main` get there. `ai-backbone.publish-on-save` is unset in this clone: on
  `cloud` every save would be a three-machine run. `radar-save` counts as strays
  only what is on `HEAD` and on neither `origin/cloud` nor `origin/main`, or a
  spec file that reached `main` refuses every Sunday save. `_backbone-tag` stays
  as the backstop: under fast-forward it names the same commit the gate does,
  and whichever is first wins. The backbone-dev skill's loop starts with
  `git checkout -B cloud origin/cloud`, publishes to `cloud`, and ends with
  `git checkout main`.

## Cost

Read 2026-09-24 on docs.github.com: GitHub Free includes 2,000 minutes a
month for the account's private repositories together (a project's CI once
used the month in two days, `docs/backlog.md` line 38); the spending limit
defaults to $0, so at 2,000 runs stop rather than bill; per-minute rates are
Linux $0.006, Windows $0.010, macOS $0.062, and how a macOS minute counts
against the included 2,000 is not stated on the page — the first run reads it
off the billing page. Taking macOS as ten and Windows as two until measured,
with the suite at *t* wall minutes: a code push costs about 11*t* + 6, a
docs-only push 2. The routine pushes code nearly every day (26 a month) and an
attended session publishes once (about 4): the free minutes hold while
*t* ≤ 6.4, and no run has ever measured *t*. The levers, in order: a cache for
the gitleaks build and the tools on macOS; macOS on fewer days until the
repository is public (see Decided); a public repository.

## Measured

The first runs, 2026-09-24, on a public repository (GitHub bills nothing: the
run's timing endpoint says 0 ms for every machine).

- Run 35976774812, private repository: no job started. GitHub: "The job was
  not started because recent account payments have failed or your spending
  limit needs to be increased". The repository went public that hour.
- Run 35978618392 (f1a4166, a code push): `look` 4 s; Linux 1 min 51 s
  with one red check; macOS 4 min 35 s with one red check; Windows: `setup.sh`
  installed everything under Git Bash, the suite ran, and the 10-minute cap cut
  it at about four fifths with 190 checks green and 219 red. `promote`
  35979675979 ran from `main`'s copy, judged the red run and wrote one `gate:`
  line on `cloud` (cedbb99, by `github-actions[bot]`: the `permissions` key
  grants `contents: write` above the repository's read default, as seen).
  `main` did not move. Two lessons: a matrix job's name carries the other
  matrix values unless the job is given a `name:` ("suite (ubuntu-latest, 30,
  false)"), which the gate now reads by prefix; and a check that fails on a
  runner must say what it saw, because nobody can type the line there.
- The two runner-only reds: a Mac runner's `ls` sorts `brain` before
  `CLAUDE.md` (locale), so the new-project check sorts in the C locale now;
  on a Linux runner `gh` sits in `/usr/bin`, inside the suite's "no tools"
  PATH, and its long refusal pushed `upstream.py`'s key phrase past the
  120-character cut of a reason, so the phrase comes first now.
- Run 35981698582 (dc3f1ec): `look` 9 s; Linux 2 min 20 s, green; macOS
  3 min 14 s, green. The change touched the workflows and `gate.sh`, so it
  reached `main` by hand (`git push origin cloud:main`) after green, and the
  Mac's backstop tagged v3.27.1 at the next session start, as designed.
- Images and tools on the runners: `ubuntu24 20260920.314.1` (Linux x86_64),
  `macos26 20260907.0351.1` (Darwin arm64), `win25-vs2026 20260907.229.1`
  (MINGW64_NT); `just 1.58.0`, `prek 0.5.3`, `uv 0.12.18`, `graphify 0.9.67`
  (installed over the 0.9.64 pin, as the routine log already says).
- Windows at 20 minutes (run 35980796058): 196 checks green, 223 red, cut by
  the cap in the same section as at 10 minutes — the second ten minutes
  bought six checks, because two checks there wait on `ps` and a measuring
  timeout. The red by section, the first lead (the runner's git checks files
  out with CRLF: two size checks fail by exactly that difference) and the
  wait are three `blocked:` lines in `docs/backlog.md` for spec 020.
- The docs-only push cf85299 (this section's first version): `look` alone, the
  suite skipped, the run green (a skipped job does not fail a run, as seen),
  `promote` 35982290661 carried it to `main` and left v3.27.1 where it was.
- Run 35981698582 (dc3f1ec) ended: Linux and macOS green, the Windows job
  cancelled by its 20-minute cap, and the run's conclusion `cancelled` —
  `continue-on-error` does not cover a cancellation. A gate that read only
  the run's conclusion would have judged nothing, and a routine's push would
  have waited on `cloud` in silence. So the gate reads the deciding jobs
  first: Linux and macOS green is green, whatever the run says.
- Caps, twice the measured time: the job Linux 7, macOS 10, Windows 10, and
  the suite step 5, 8 and 8 — the step's own cap ends a hung suite as a
  failure the run tolerates rather than a cancellation, so a carry waits ten
  minutes at most. A code push costs about four wall
  minutes of gate on the deciding machines; the cost question is answered by
  the public repository: nothing.

## Not doing

- Windows green: `setup.sh` has no Windows branch and `self-test.sh` uses
  `ln -s`, `ps -o` and `python3` in ways MSYS may not follow. Report-only here;
  its first log becomes `blocked:` backlog lines for a spec of its own.
- Branch protection or rulesets (403 on Free); a merge made on a runner;
  re-running the suite on `main` after a carry (its head is the tested commit);
  cancelling superseded runs (the ci-check rule keys runs on the commit, and
  with publish-on-save off a burst of pushes does not happen).
- A cache for the tools, a pinned `macos-NN` image, a sha-pinned
  `actions/checkout`, `just ci` finding a promote run by commit: each wants a
  measured run first.
- Any change to the stored routine prompt, the scheduler, or what a person
  types in a project.
- Pulling the backbone into projects from GitHub instead of the sibling clone,
  and the Mac clone as backup only: spec 019.
- Making the repository public: decided as the answer to a budget that runs
  over, but done as its own spec, after the clean-up `docs/backlog.md` line 61
  describes and an audit.

## Decided

- 2026-09-24, the maintainer: GitHub Actions is switched on for this
  repository. The switch is made when the new workflows are in place (the
  sixth task), not before: the old `checks.yml` would run the suite on every
  note a project sends to `main`. Today Actions is off in all five private
  repositories of the account, so the backbone is the free pool's only user.
- 2026-09-24, the maintainer: if the first measured run shows the month over
  the 2,000 free minutes, the repository becomes public, which makes the
  minutes free — after the clean-up `docs/backlog.md` line 61 describes and
  an audit, as its own spec. Until it is public, the macOS leg runs on as many
  days as the measured minutes allow (the agent sets the number from the
  measurement and writes it here), so the gate never stops mid-month; Linux
  decides on the other days.

## Questions

None open.

## Acceptance

- [x] `just self-test`: `gate.sh look` says docs-only exactly when the files
      that differ from `main` are all routine-log, backlog, radar.toml or
      specs, chooses the suite for any other path, `docs/01-getting-started.md`
      included, and answers the same in a clone of depth one.
- [x] `just self-test`: `gate.sh carry` with a green event against the fixture
      repository fast-forwards `main` to the tested commit and pushes the tag
      `v<line 1 of core.just>` in one atomic push; run again it creates nothing
      and writes nothing; a tested commit already on `main` writes nothing; a
      `cancelled` conclusion writes nothing.
- [x] `just self-test`: `gate.sh carry` with a red event and a stand-in `gh`
      writes exactly one line beginning `- <date> gate: cloud not promoted — `
      to `docs/routine-log.md` on `cloud`, naming the failed deciding job and
      its `FAIL` names and none from the Windows job; `main` and the tags are
      untouched.
- [x] `just self-test`: `gate.sh carry` refuses a candidate whose
      `.github/workflows/` or `gate.sh` differs from `main`'s, one `main` cannot
      fast-forward to, and one whose suite was due but did not run, each with
      the reason in that line and `main` untouched; a tag that exists at another
      commit lets `main` through alone and the line says the tag stood.
- [x] `just self-test`: `_backbone-level` calls a no-branch checkout up to date
      at `origin/cloud` or at `origin/cloud` merged with `origin/main`; a clone
      on `cloud` takes what is new by a merge and never pulls `main`; a clone on
      `main` behaves exactly as before, a missing `cloud` branch included; the
      two-day line appears in both voices when the oldest unpromoted non-merge
      commit is two days old and not when the tip alone is; the rails line names
      `.github/workflows/` and `gate.sh`; from a project, a sibling on `cloud`
      is named and `template-update` refuses to copy from it.
- [x] `just self-test`: `backbone-note` inside a `cloud` or no-branch checkout
      saves, pushes nothing and says the note rides the push; from `main` it
      sends as today; `publish` and a publish-on-save `save` on `main` inside the
      backbone say "not sent" and name `git checkout -B cloud origin/cloud`;
      `radar-save` saves while a code commit sits on `cloud` and a spec file
      reached `main` since the last carry.
- [x] `just ci-check` passes on both workflow files without a skip marker; the
      stored prompt block in `docs/01-getting-started.md` is byte-identical
      before and after; the scheduler's configuration is unchanged;
      `git config --get ai-backbone.publish-on-save` in this clone prints nothing.
- [x] First real runs, read by their run ids: a docs-only push to `cloud` runs
      `look` alone and is carried; a code push runs `look` and three machines; a
      red Windows leg leaves the run green and the carry runs; after a green
      run `main`'s head is the tested commit, the tag exists on it, and
      `just session-start` in a project pulls it. The wall and billed minutes
      per machine, what the billing page counted, the image names and the
      runner's `just` version are written into this spec, and the cost question
      is answered with the number.
- [ ] The next unattended run starts from `origin/cloud`, pushes `HEAD:cloud`,
      tags nothing, and its log line says so; the gate carries it.
- [x] `docs/01-getting-started.md` no longer says the Mac tags a version;
      `docs/how-it-works.md`'s two charts show `cloud` and the gate between the
      agent and the version; spec 016 carries a one-line pointer; backlog line
      62 names this spec; the backbone-dev skill's loop works on `cloud`.

## Tasks

- [x] `.ai-backbone/gate.sh` (`look`, `carry`), and in `self-test.sh` a `cloud`
      branch in the fixture repository, a stand-in `gh` (the run's conclusion
      and commit come in as `GATE_ENDED` and `GATE_SHA`, so no event file is
      needed), and the gate checks above.
- [x] `core.just`: `_backbone-level` (target `main` or `cloud`, both-ancestors
      up to date, merge on `cloud`, the explicit `cloud` fetch, the two-day line
      from the oldest unpromoted commit, the sibling-on-cloud line, the rails),
      `template-update`'s refusal, `backbone-note` (a `cloud` or no-branch
      checkout saves and rides the push), `publish` and `save` refusing `main`
      inside the backbone, `_backbone-tag`'s comment; the self-test checks that
      pin `main` rewritten and the new ones added.
- [x] `Justfile`: `radar-save` strays against both branches, with its check.
- [x] `routine.md` (intro, steps 4, 6, 12, Sunday, quirks, Never), the
      backbone-dev skill (the loop on `cloud`), `radar.py` line 6.
- [x] `checks.yml` rewritten and `promote.yml` added; `just ci-check` green.
- [x] `docs/01-getting-started.md`, `docs/how-it-works.md`, the spec 016
      pointer, backlog line 62, `CHANGELOG.md` 3.27.0, `core.just` line 1 →
      3.27.0. Then, once, by the agent: `git config --unset
      ai-backbone.publish-on-save`; switch Actions on; push the same commit to
      `main` and to `cloud` by raw `git push` (the last hand push: `promote.yml`
      and `gate.sh` must be on `main`, and `checks.yml` on `cloud`, before the
      first push is judged); this clone back on `main`.
- [x] Push a docs-only line and then a code change to `cloud`; read both runs
      by id (`gh run list`, `gh run view`, the run's timing endpoint) and the
      billing page; write the measured minutes, the images, the runner's `just`
      and the three GitHub rules as seen into this spec; set each cap to twice
      the measured time; answer the cost question with the number.
- [x] Read the Windows leg's first log; one `blocked:` backlog line per cause.
- [ ] The morning after: read the first unattended run; anything off becomes a
      fix on `cloud` or a note. Walk Acceptance; `status: done`.
