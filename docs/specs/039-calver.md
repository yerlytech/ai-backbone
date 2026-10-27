---
status: done
date: 2026-10-23
---

# 039 — CalVer for every project

## What

Every project built on this backbone numbers its versions `YY.M.PATCH`: the
last two digits of the year, the month with no leading zero, and a patch that
starts at 0. October 2026 is `26.10.0`, then `26.10.1`, `26.10.2`; January 2027
is `27.1.0`. The backbone itself takes the same scheme from this publish on.

`YY.M.PATCH` is still valid Semantic Versioning (three dot-separated numbers),
so cargo, npm, the App Store and the semver tools the backbone already uses
keep working, and a CalVer version always compares higher than any `0.x`,
`1.x` or `3.x` version that came before it. `just release` cuts the next CalVer
version; the draft-then-tag two runs stay as they are (spec 022).

## Why

Version numbers were SemVer, read from the kinds of the commits since the last
tag. To a person reading two projects, `2.3.1` says nothing about when it was
made, and a project that had reached `3.x` could not move down to the old
SemVer sequence and still sort correctly. A date-based version says at a glance
which release is newer and when it was cut, and it still sorts as SemVer.

An old SemVer project moves without a step of its own: its next `just release`
simply cuts this month's `YY.M.0`, because a CalVer number is higher than any
SemVer number it could have had. A project whose last tag is `v0.4.2` continues
at `26.10.0`, not `0.4.3`.

The step arguments `patch`, `minor` and `major` stay accepted, because habits
and scripts name them, but all three now mean "the next CalVer": the month's
first patch when the last tag is from another month, otherwise the last patch
plus one. The line that says so is printed. The old rule that `1.0.0` is cut
only on the maintainer's word is gone, because there is no `1.0.0` to cross.

The backbone's own versions follow the same scheme. This publish is `26.10.0`;
the version on line 1 of `core.just` is what `template-update`, the freshness
block, `just stable` and a project's "behind" check read, and they compare it
numerically, so `26.10.0` reads as newer than `3.46.0`.

The backbone does not touch a project's `Cargo.toml`, `package.json` or
`pubspec.yaml` version. It already leaves the manifest alone unless the
language layer provides `_set-version`; this spec does not change that. The tag
and `CHANGELOG.md` are the project's version of record.

## Not doing

- No migration recipe and no renumbering of old tags. History keeps the tags it
  has; the next release is the CalVer of the day.
- No change to how `_set-version` writes a manifest version, and no promise
  that a manifest version is CalVer. Projects that want one move it in their own
  language layer.
- No new sort or comparison code: the existing numeric comparison works for
  CalVer and is covered by a test.

## Questions

None. The maintainer decided CalVer `YY.M.PATCH` at the company desk on
2026-10-24 and approved the work.

## Acceptance

- [x] `just release` in a project with no tag cuts this month's `YY.M.0`.
- [x] A second release in the same month cuts the next patch, `YY.M.1`.
- [x] A release in a new month cuts `YY.(M+1).0`.
- [x] A project whose last tag is `v0.4.2` cuts `26.10.0`, not `0.4.3`.
- [x] `patch`, `minor` and `major` are accepted, mean the next CalVer, and say
      so in one line.
- [x] An existing tag refuses the release, as before.
- [x] A new `CHANGELOG.md` says the versions follow CalVer `YY.M.PATCH`
      (https://calver.org), also valid Semantic Versioning.
- [x] The session skill's "Public standards" and every doc that names SemVer for
      projects say CalVer.
- [x] `core.just` line 1 says `26.10.0`, and the CHANGELOG has its entry.
- [x] `just stable 26.10.0`, `template-update`, the freshness block and a
      project's "behind" check read `26.10.0` as newer than `3.46.0`.
- [x] `just self-test` is green.

## Tasks

- [x] Write this spec, approved.
- [x] `just release`: the CalVer rule, the step arguments, the CHANGELOG header,
      no `1.0.0` rule; self-test cases for first release, same month twice, a new
      month, a last tag of `v0.4.2`, and an existing tag.
- [x] The session skill, the spec skill and the docs: CalVer for projects.
- [x] The backbone's own version to `26.10.0`: `core.just`, the CHANGELOG entry,
      and a self-test that the version comparison reads it as newer than `3.46.0`.
