---
status: done
date: 2026-10-21
---

# 036 — Secrets live in brain/, a link stays where the tool reads them

## What

A project's secret files (the ones `_secret-files` lists and git ignores: `.env`,
`.env.*`, `.envrc`, keys, certificates, keystores, provisioning profiles) move
into `brain/secrets/<the same path>`. At the old path a relative link stays, so
every tool still finds the file where it looked before. `just secrets-to-brain`
does the move, file by file, and says each one. `just secrets-back` undoes it.
After the move the second copy holds brain/ alone: the secrets are in it.

## Why

AGENTS.md section 7 says keys and certificates live in `brain/`. In practice they
sit in the project root, because the program reads them there, and doctor
warns about a key outside brain/ with no way to fix it. The second copy works
around this with a `secrets/` folder beside `brain/`. On 2026-10-21 the
maintainer asked that each project's cloud copy hold `brain/` and nothing else,
and that secrets be inside it. A link gives both: one real place, in brain/,
and the tool unchanged.

## Not doing

- No encryption and no secret manager. The file stays a plain file on this Mac,
  as it is today; brain/ is already outside git and copied by `_vault-copy`.
- No change to how a server reads its secrets (`/run/secrets`, `*_FILE`).
- No `--delete` on the second copy. The old `secrets/` folder there stays as it
  is; `about-this-copy.txt` says it is no longer written.
- An `.env.example` never moves: it is committed on purpose.
- A file under a build or dependency folder is never touched (same prune list
  as `_secret-files`).

## Questions

None open. Approved by the maintainer on 2026-10-21: move and link, the cloud copy holds brain/ alone.

## Acceptance

- [x] `just secrets-to-brain` moves each git-ignored secret file to
      `brain/secrets/<path>`, keeps its mode (0600 stays 0600), and leaves a
      relative link at the old path. It refuses a file git tracks, a path
      already linked, and a target that exists; it prints each file moved.
- [x] Run twice, it changes nothing the second time.
- [x] `just secrets-back` puts each file back at its path, removes the link,
      and leaves `brain/secrets/` empty.
- [x] A link at the old path is still ignored by git (`git check-ignore`), and
      `just save` never stages one. A test proves it with an `.env` in the
      root and one two folders down.
- [x] `_vault-copy` copies brain/ with the secrets in it as files. A secret
      file still outside brain/ is still copied to `secrets/` as today, so
      nothing is lost while a project has not moved yet.
- [x] doctor no longer warns about a key that is a link into `brain/secrets/`,
      and warns about a link whose file is missing.
- [x] The core rules say: secrets live in `brain/secrets/`; an agent never
      prints, copies or quotes one, and reads one only to move it.
- [x] Tested on macOS and Linux; walked on one real project with a root `.env`,
      what reads it started from the link.
      2026-10-21: the checks of 5a77ab4 green on Linux and macOS. Walked on
      six projects the same evening (seven files, one of them two folders
      down); each link resolves and is ignored by git, and a Compose file
      that refuses to start without its .env's password read it through the
      link.

## Tasks

- [x] `secrets-to-brain` and `secrets-back`, with tests (root, nested, mode,
      refusal cases, run twice).
- [x] `_vault-copy` and doctor follow the links; their tests.
- [x] Rules, docs, changelog; release.
- [x] Each project moves on its next session (a note to every project).
      Done for every project at once in the batch update of 2026-10-21.

## Notes

Docker Compose `env_file:` and a bind mount follow a link on the host; Cargo,
Flutter and dotenv readers open the file through it. A Docker build context
never sees one: images are built from a clean copy of a commit, which holds no
secret. A tool that refuses a link turns up in the walk and goes in this spec
as an exception that stays a plain file.
