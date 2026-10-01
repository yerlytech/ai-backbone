# Audit lenses

The questions an audit asks about this project. One agent takes each one.

A lens is a question about this codebase, not a category. "Security" produces
findings about security in general, which are true of every project and useful
to none. "Can any path reach another tenant's database?" produces findings about
this one.

The five below are the same in every project and are worth keeping. The rest
come from what this project has decided: read `docs/adr/` and the acceptance
lists in `docs/specs/`. A decision is a claim, and a claim can be violated, so
every decision that matters deserves a lens.

Run them with the `audit` skill, at the end of a phase and before a release.

## The five that are always here

### Documents against code

Every claim in `docs/` that is not true, is true only in one mode, or is true
only on a path nobody takes. Walk the acceptance list of the last spec line by
line and find the code or the test that makes each line true.

This is the lens that catches an agent's own optimism, which is why it is first.

For every claim about what a library, a database or a tool does, ask which
version it was measured on. A claim with no version was written from memory,
and memory is of an older version than the one this project pins.

### Tests that prove nothing

Which tests would still pass if the behaviour they describe were broken?
Assertions that cannot fail, tests that assert on their own setup, names that
promise more than the body checks, and rules the documents name that no test
covers. Name the test and say what it fails to catch.

### What leaks

Does any refusal, log line, response body or file name carry something the
person on the other side should not have: internal prose, a stack trace, a path,
a token, a password, another customer's data? Check what a failure says as
carefully as what a success says.

### The second day

Upgrade and restore. A database with data in it, brought to the next schema. A
backup taken and put back. A server restarted while something was half done. A
thing that works on an empty database and not on a full one.

Read what builds the app somewhere other than the development machine as part
of this: CI, the image, the compose file, the store build, the install guide.
Is the toolchain each of them installs at least what the app and every
dependency declare they need? No test that runs on the development machine can
see it. In a Rust service, a dependency asked for Rust 1.94 while the Dockerfile
said 1.90, and the build would have failed at the first crate. In a Flutter app
the same gap sits between `environment:` in `pubspec.yaml` and the Flutter that
CI installs, between the iOS deployment target and what a plugin asks for, and
between Android's minSdk, Gradle, its Android plugin, Kotlin and the JDK.

### The rules against each other

Rules are added one at a time, months apart, each sensible on its own. Read the
rule file, the ADRs and the specs as one document and find the pairs that cannot
both be followed: a later decision that quietly reverses an earlier one without
saying so, two documents that name the same thing differently, a rule whose
words are wider than its author meant and now forbid something the product does.

For each pair, say which one the code actually obeys. That is the honest answer
to which rule is real, and it is usually the older one, because the newer one
was never enforced anywhere.

## This project's own

<!-- One heading per lens. Name the files to read and the question to ask.
     Delete this comment when the first one is written. -->
