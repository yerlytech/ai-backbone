---
status: done
date: 2026-10-21
---

# 037 — Windows reports, Linux and macOS decide the carry

## What

The Windows suite moves out of the checks run into a workflow of its own,
started by the same push to cloud. The gate and `just carry` read only the
checks run: the look, Linux and macOS. A carry no longer waits for Windows.
Windows still runs on every push that needs the suite, and its answer is
read where it matters: `just carry` says the newest Windows result for the
commit (green, red with its FAIL names, or still running), and `just release`
refuses to tag a commit whose Windows run is red or missing.

## Why

Since spec 020 (the maintainer, 2026-09-24) Windows decides, and a carry
waits for the whole run. Then the Windows suite took 17 minutes; on
2026-10-21 it took about 40, one run hit its 44-minute cap with every check
green so far, and a carry waited 45 minutes for an answer Linux and macOS
had given in 15. On 2026-10-21 the maintainer asked for faster carries and
kept the backbone public (Actions are free for a public repository; a
private one would spend the monthly minutes in a few pushes, a macOS minute
counting ten). The suite already runs in full on this Mac before every save
of the core, so the carry is not the first time a change is tested.

## Not doing

- Windows is not dropped and not made nightly: it runs on every push.
- No change to which pushes run the suite (`gate.sh look`).
- No new runner, cache or paid machine.
- The caps stay as measured; Windows keeps its 44 and 48 minutes.

## Questions

None open. Approved by the maintainer on 2026-10-21: the backbone stays
public, and the carry stops waiting for Windows.

## Acceptance

- [x] `.github/workflows/windows.yml` runs the Windows suite on a push to
      cloud when `gate.sh look` says suite, with the same steps and caps as
      today; checks.yml's matrix holds Linux and macOS only.
- [x] `gate.sh`'s `suite_green` reads Linux and macOS; a Windows job in the
      checks run, if one ever returns, is ignored, not required.
- [x] `just carry <commit>` prints the commit's Windows result in one line:
      green, red with up to five FAIL names, running, or none.
- [x] `just release` refuses while the commit's Windows run is red, running
      or missing, and says which; the gate's tests and the release's tests
      cover each case against a fake `gh`.
- [x] A red Windows run on cloud appends one `gate:` line to
      docs/routine-log.md naming its FAIL names, as a red Linux does today.
- [x] Measured on the first push after the change: the carry is possible
      when Linux and macOS end, and the time is written here.
      2026-10-21, 90c4448: the checks run ended green in 12 minutes with
      Windows still running; carried by hand (workflow files changed).

## Tasks

- [x] windows.yml and checks.yml split; ci-check accepts the new file.
- [x] gate.sh and carry; their tests.
- [x] release refuses on Windows red or missing; its tests.
- [x] Docs (spec 020's note, getting-started's gate section), changelog;
      the attended carry of the workflow change (`git push origin <commit>:main`
      after green checks, as the gate's rule for workflow changes says).
