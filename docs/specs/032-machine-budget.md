---
status: approved
date: 2026-10-17
---

# 032 — One disk, many projects; one queue, many builds

Asked for on 2026-10-17 by the managing session as backbone work.
Closes the backlog lines n-86a7c9 and n-baf5fe. The third line it sent,
n-38c09b, is the managing project's own recipe (`library-send` in its Justfile): the
one-line fix went back to that session, and the line leaves this backlog.

## What

Three changes, all in the build plumbing every Rust project shares:

1. **`just doctor` adds up the caps.** It finds the Rust projects on this
   machine the way `project-note` does (next to the backbone, one and two
   folders down), reads each one's `ai-backbone.build-cap` (its own, else the
   global one, else 60), and warns when the sum is more than half the disk.
   The warning gives the numbers and a cap that would fit (half the disk
   divided by the number of projects). It changes nothing itself.
2. **Under disk pressure, the trim also looks at idle projects.** When less
   than 15% of the disk is free (the point where the trim already halves a
   folder's cap), the hourly background trim, after its own folder, goes
   through the other projects' build folders. It starts with the one built
   longest ago and stops when 20% of the disk is free. A folder counts as idle
   when nothing has been built in it for 7 days and nothing uses it now. What
   it may remove there is the open question below.
3. **The build queue has one limit, and it is short.** Today a build waits in
   two phases, each up to `BUILD_WAIT_MINUTES` (20): first behind the tickets
   ahead, then behind any running compiler. So one 40-minute build in one
   project can hold a small build elsewhere for up to 40 minutes. The new
   rule: one limit for the whole wait, 5 minutes by default
   (`BUILD_WAIT_MINUTES` still overrides it). When the limit passes, the build
   goes on with half the cores, as it already does after a long wait: that cap
   is what protects memory at link time, not the order. While it waits, it
   says which project holds the turn and since when.

## Why

On 2026-10-14/15 the disk lost about 60 GB an hour while every project stayed
under its own cap, so nothing was trimmed: 13 Rust projects × 150 GB = 1950 GB
of caps on a 926 GB disk. The trim's protection ("pieces the last day's builds
used") is measured from each folder's own newest build, not from today. So an
idle project's last working set stays forever, however full the disk gets.

The queue: agents bypassed it with `BUILD_WAIT_MINUTES=0` because a single long
`check-all` held every other workspace. A queue that people switch off
protects nothing.

## Not doing

- Not changing the global cap of 150 (`git config --global
  ai-backbone.build-cap`). That is the owner's call; doctor only says the sum.
- No memory measurement for the queue. Half the cores after the limit is the
  rule already in place and measured; reading free memory differs on every OS.
- No new file in the core (the new-project file ceiling of 60): the code goes
  into `buildtrim.py` and `core.just`.
- Windows: the trim already removes nothing there (cargo's locks cannot be
  read); the doctor sum works the same everywhere.

## Questions

- **What may the trim remove in an idle project when the disk is full?**
  (a) Everything a build would make again, oldest first, until 20% is free.
  That project's next build compiles from nothing, once (minutes to an hour
  for a big workspace). Frees the most.
  (b) Only what that project's newest build no longer reaches (left behind by
  an update or a feature change). No rebuild cost, but it may not free enough;
  doctor then says so.
  My recommendation: **(a)**. A full disk stops every project. One rebuild in
  a project untouched for a week is the cheaper price. Spec 027 approved
  removing old pieces automatically, but not an idle project's working set,
  so this needs the owner's yes.
  Relayed by the managing session on 2026-10-17 as the owner's answer: (a),
  on three conditions: the oldest and longest idle first, never a folder
  cargo is working in, and one log line saying what was removed. Confirmed
  by the owner in this repo's session the same day: approved.

## Acceptance

- [ ] doctor, with caps summing to more than half the disk: one warn line with
      the sum, the disk size, the project count and a cap that fits; none when
      they fit.
- [ ] With the disk under 15% free (self-test: a fake disk size), an `auto`
      trim also trims an idle sibling's cargo folder, least recently built
      first, and stops at 20% free; a sibling built in the last 7 days, or with
      a build running in it, is left alone; each folder's log gets its line.
- [ ] A build behind another waits at most `BUILD_WAIT_MINUTES` (default 5) in
      total, queue and running together, then goes on with half the cores;
      its wait line names the holding project and how long it has held.
- [ ] `BUILD_WAIT_MINUTES=0` still switches the wait off.
- [ ] Self-test green; no Rust build needed (stubs, as in spec 027/029).
- [ ] Green on the three machines, released; the managing session told the
      version.

## Tasks

- [ ] doctor's machine sum, with self-test cases.
- [ ] The queue: one limit, default 5, the holder named; self-test cases.
- [ ] The idle-folder trim under pressure; self-test cases with a fake disk.
- [ ] docs (README's build section, the recipe comments), CHANGELOG; through
      the gate; tagged; the managing session told.
