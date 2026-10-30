---
status: approved
date: 2026-10-31
approved: the maintainer, 2026-10-31, every recommended answer but the first one's ssh part (below)
---

# 041 — Secrets in the operating system's keystore

The number is 041. Spec 040 is the kimi worker, already on its own branch
(`040-kimi-worker.md`, 2026-10-31). This file took the next free number so
the two do not collide.

## What

A secret stops being a file a worker can open. It lives in the operating
system's keystore, under one name, and a recipe reads it only at the moment
of use. On macOS that store is the login keychain: one generic password item
per secret, created with `-T ""`, which `security(1)` says removes the
creating application's default access without a warning. Whether the read
then raises a dialog is unverified, and is the measurement in Tasks. On Linux the store
is Secret Service, through libsecret (`secret-tool`). On Windows the store is
one file encrypted with DPAPI. The name is the same on each: service
`ai-backbone`, account `home/<path>` for a file under the home directory and
`<folder>/<path>` for a file in a project. Nothing in git holds an account
name, a home directory, or a secret.

`just with-secret <account> -- <command>` is the only reader. It passes the
secret on that command's standard input, never as an argument, never in the
environment, and never as a file left behind. It prints nothing of the value.
Its failure is one line naming the account and the reason (absent, locked,
nobody there to approve). `just secrets-to-keystore` moves each file this
spec takes, deletes the file and the spec 036 link, and leaves no copy,
including on failure after a successful store. A second run changes nothing.

Every worker `just delegate` starts is denied the keystore commands and the
secret paths. Grok and opencode gain the command denies beside the list they
already have. Claude Code gains the same command denies and `Read` denies in
`.claude/settings.json`, merged the way the delegate allow rules are merged,
so a rule a project already wrote stays. The suite proves all of this against
a fake keystore and never calls the real one.

No model may read a key. That covers Grok, Claude, Kimi, DeepSeek, and a
worker added later. Kimi and DeepSeek on this branch run as opencode's ladder,
so opencode's deny covers them.

## Why

Measured on the maintainer's Mac on 2026-10-31: the keys are files of mode
0600. The set was `~/.aws/credentials`, `~/.appstoreconnect/config.env`, keys
under `~/.config/<tool>/`, `~/.ssh`, gh's `hosts.yml`, the workers' own auth
files, and `brain/secrets` and `brain/03-stack` across eleven projects. Every
worker runs as that same user, so 0600 stops nobody. The delegate deny lists
block some commands (push, merge, rebase, checkout, switch, reset, branch
deletion, tag, publish, ship, deploy, release, undo, gh, curl, ssh, rm, and
the wrappers sh, bash, zsh, eval, xargs, env). None of them blocks
`security find-generic-password`, `security find-internet-password`,
`secret-tool lookup`, or a read of those paths. Claude's delegate run adds no
deny of its own; `.claude/settings.json` denies a few `Bash` spellings and no
`Read`. Left alone, a worker reads the file.

Spec 036 put the project's secret files in `brain/secrets/` and left a link
where the tool looks. That is still a file of mode 0600. This spec is the
step past that, for the files that move.

Takes the secret-path half of backlog n-5b9b58 (deny reads of `~/.aws`,
`~/.appstoreconnect`, `brain/03-stack`, `.env`, and the rest of the set
above). The network half of n-5b9b58 stays on that line. n-fc65ca stays open:
whether grok's `--deny` is stepped around by a wrapper was not measured, and
this spec adds deny text on that same unmeasured mechanism.

## Not doing

- A third-party manager (no 1Password, no cloud vault).
- Any test, recipe, or agent run that calls the real keychain, Secret
  Service, or DPAPI, or that reads a real secret. The suite uses a fake.
- Copying a keystore item into CI. CI already has the platform's own secret
  store. The reader is not called there.
- An undo that writes the secret back to a file.
- Denying every `security` subcommand, or every language binding of the
  keystore. The commands denied are the ones that print a password.
- Treating the command deny as a security boundary. `docs/how-it-works.md`
  already says Claude's list matches command text. Grok's own guide says the
  same of its rules, and points at the sandbox for an OS-level deny.
- Closing n-fc65ca, or the network half of n-5b9b58.
- Editing spec 036 before this spec is approved.

## Answers

The maintainer, 2026-10-31: every recommended answer below, with one change to
the first. An ssh private key stays a file opened by path, but its passphrase
lives in Keychain through macOS's own ssh (`UseKeychain yes` and
`AddKeysToAgent yes` in `~/.ssh/config`, `ssh-add --apple-use-keychain`), the key
file is encrypted with that passphrase, and workers stay denied `~/.ssh`, `ssh-add`
and the agent's socket; a key without a passphrase is reported by the migration
recipe, never silently left. Facts about Apple's ssh options are checked against
`man ssh_config` on the machine before they are relied on.

1. **Which files move, and which stay files?** Recommended: move token files
   the reader can hand to a command on standard input: `.env` (not
   `.env.example`), `.envrc`, `~/.aws/credentials`,
   `~/.appstoreconnect/config.env`, gh's `hosts.yml`, the workers' credential
   files, and those same names under `brain/secrets/`. Leave `~/.ssh` private
   keys, certificates, keystores, and provisioning profiles as files under
   spec 036. Deny workers those paths either way. `brain/03-stack` is denied
   and is not moved wholesale: only a file there that matches the list moves.
   Why it matters: a generic password is one value, and ssh, a certificate,
   and a provisioning profile are opened by path. Moving those would break
   the tool, and a temp file of mode 0600 is the hole this spec exists to
   close.

2. **How does the command receive the secret?** Recommended: on its standard
   input, never as an argument and never in the environment. `ps -E` displays
   the environment of your own processes (man ps, read 2026-10-31), so an
   environment variable is visible to every worker on the machine. A program
   that can only read a path or an environment variable is in question 1's
   "stays a file" set, unless the maintainer says it moves and accepts that
   window. Workers are denied `just with-secret` as well as the keystore
   commands, so a worker never becomes the process that holds the secret.
   Why it matters: a secret that is printed, passed as an argument, or left
   in a file is a secret the worker can read.

3. **What runs when nobody can approve a prompt?** Recommended, one handle
   each. CI: the key stays on the server, in the platform secret store, and
   the reader is not called. A launchd job that is not a model: a separate
   item trusted only to that job's binary (`-T` that one path), never to a
   shell and never to a model CLI. The night chain: the step is skipped and
   named in the morning summary; it does not run. A model is never a trusted
   application. Why it matters: a night job that can read a key is a model
   reading a key.

4. **One keychain, many projects.** Recommended: home files are `home/<path
   under the home directory>`. Project files are `<the folder's name>/<path
   inside the project>`. The migration refuses when that account already
   exists and the stored bytes differ. A renamed folder is a line in the
   morning, not a second copy of the secret. Why it matters: this Mac holds
   many projects and one login keychain.

5. **Grok's kernel sandbox as well as the command deny?** Recommended: yes.
   The delegate run adds a custom sandbox profile whose `deny` lists the same
   paths (`~/.ssh`, `~/.aws`, and the rest), because grok 1.0.62's sandbox
   guide says a non-empty `deny` is kernel-enforced and a `~/` entry is the
   real home directory. Acceptance does not rest on it until a run measures
   it. n-fc65ca stays open either way. Why it matters: the command list is a
   fence. The guide itself says it is not the OS boundary.

6. **Windows, until DPAPI is read from its own page.** Recommended: ship the
   encrypted file, and say in the docs that the deny list is the only control
   against a worker there. Do not describe a dialog on Windows. The Mac
   dialog is the control this spec wants, and it is unverified even on the
   Mac (sources below). Why it matters: calling Windows the same lock as the
   Mac would be a false promise.

## Acceptance

- [ ] `just secrets-to-keystore` stores each file question 1 moves, deletes
      the file and a spec 036 link at the old path, prints `moved <path>` and
      never the bytes, and leaves no copy. Run twice, it changes nothing.
      A store that fails leaves the file where it was. An account that already
      holds different bytes is refused, and the file stays.
- [ ] `just with-secret <account> -- <command>` runs the command with the
      secret on its standard input. The command's output is the recipe's
      output. The value is not an argument, not in the environment, and not
      in a file afterwards. A missing account, or a fake that says nobody is
      there to approve, exits non-zero with one line and no value.
- [ ] With `AI_BACKBONE_KEYSTORE` set to a temp directory, neither recipe
      executes `security` or `secret-tool`. The suite's PATH has a fake of
      each that exits 99 if called, and the tests do not exit 99. No test
      calls `/usr/bin/security`.
- [ ] Grok's delegate argv and opencode's generated config deny
      `security find-generic-password`, `security find-internet-password`,
      the same two with `/usr/bin/security`, `secret-tool lookup`,
      `/usr/bin/secret-tool lookup`, and `just with-secret`. A fake worker
      records the argv and the config. The opencode denies come after the
      shell allow, which is the order spec 038 measured as the one that wins.
- [ ] `.claude/settings.json` denies those same commands and denies `Read` on
      `**/.aws/**`, `**/.appstoreconnect/**`, `**/.ssh/**`,
      `**/.config/gh/hosts.yml`, `**/.grok/auth.json`,
      `**/.grok/mcp_credentials.json`, `**/brain/secrets/**`,
      `**/brain/03-stack/**`, `**/.env`, `**/.envrc`, and
      `**/ai-backbone/keystore/**`. The merge leaves a rule that was already
      in the file. The committed file contains no home directory and no
      account name. `.env.example` is not in the deny list.
- [ ] doctor warns when a regular file is still at a path this spec denies,
      and is quiet when that path is gone because the account is in the fake
      store.
- [ ] The night-chain rule and the CI rule are in the spec skill and
      `docs/how-it-works.md`: a night step that needs a secret is skipped and
      named in the morning; CI does not call the reader.
- [ ] Spec 036 gains one line pointing here for the files that moved, once
      this spec is approved and the move exists. Until then 036 stays as it
      is.

## Tasks

- [ ] The fake store, `just with-secret`, and its tests. The recipe calls
      `security` and `secret-tool` by name on `PATH` only when
      `AI_BACKBONE_KEYSTORE` is unset; the suite always sets a temp directory.
- [ ] `just secrets-to-keystore` for the files question 1 settles, with the
      refusal cases, the second run, and the deleted link. Docs for both
      recipes.
- [ ] The delegate denies for grok and opencode, the Claude `Read` and `Bash`
      denies merged into settings, and the fake-worker tests. The opencode
      path rule is copied from the pinned opencode's permission schema on the
      day it is written (pin 2.1.2; the schema was not in the 2.2.3 cellar
      files read on 2026-10-31), and the spec records that page and date.
- [ ] doctor's warning, the night-chain paragraph, the CI paragraph, and the
      one line on spec 036.
- [ ] An attended measurement, after approval, with a throwaway item whose
      value is the word `fake`: create it with `-T ""` and `-w` at the end of
      the command so the value is prompted, then see whether
      `find-generic-password -w` asks. Record what happened in this spec.
      The suite does not do this. The same session reads `secret-tool`'s man
      page on Linux, or the dated upstream page, and Microsoft's DPAPI page,
      and replaces the unverified lines below with what those pages say.

## Sources

Read on 2026-10-31, and safe to treat as fact:

- `security(1)`, file `/usr/share/man/man1/security.1`, file date 2026-10-23.
  `add-generic-password` requires `-a account` and `-s service`. `-w` is the
  password, and the page says to put `-w` at the end of the command to be
  prompted. `-A` lets any application read the item without warning, and the
  page calls that insecure. `-T appPath` names an application that may read
  the item; more than one `-T` is allowed. "By default, the application which
  creates an item is trusted to access its data without warning. You can
  remove this default access by explicitly specifying an empty app pathname:
  `-T ""`." With no keychain named, the item goes to the default keychain.
  `find-generic-password -g` prints the item and the password; `-w` prints
  the password only. The same `-g` and `-w` exist on
  `find-internet-password`. `set-generic-password-partition-list` sets an
  extra ACL field that limits access by code signature, and changing it
  requires the keychain's password.
- `ps(1)`, read the same day. `-E` displays the environment, and it does not
  reflect changes made after the process launched. The default listing is
  your own processes.
- Grok 1.0.62, `~/.grok/docs/user-guide/22-permissions-and-safety.md` and
  `18-sandbox.md`, the copy installed with the binary dated by `grok
  --version` as 1.0.62. A `Read` rule is `Read(**/.env)` or an absolute
  `Read(/Users/you/private/**)`. In a pattern, `*` and `?` do not cross `/`
  and `**` does. A leading `~/` in a `Read` pattern is literal glob text, not
  the home directory; a tool path that starts with `~` is matched literally
  because the tool expands `~` after the check. `deny` wins over `allow`.
  A `Read` deny also applies to a path a shell command names, including a
  literal script passed to `bash`, `sh`, `dash`, `zsh`, or `ksh` with `-c`.
  The wrappers peeled before a `Bash` rule is matched include `env`. The
  sandbox guide: a non-empty custom `deny` is kernel-enforced (Seatbelt on
  macOS, a bind-over on Linux); `deny = ["~/.ssh"]` is the real home `.ssh`;
  a relative glob matches only inside the workspace; a bare `~` also covers
  `~/.grok`, which the guide says not to deny as a whole.
- Grok 1.0.62, `02-authentication.md`. Credentials are `~/.grok/auth.json`.
  MCP OAuth tokens are `~/.grok/mcp_credentials.json`. Both are written mode
  0600. The page says anyone with filesystem access to those paths can use
  them.
- This repo, read the same day. Delegate denies are in
  `.ai-backbone/core.just` (`delegate_grok`, `delegate_opencode`);
  `delegate_claude` passes no deny flags. `.claude/settings.json` has `Bash`
  allow and deny only. Spec 038 measured opencode 2.1.2 on 2026-10-22:
  without `--standalone` the deny is not applied, a shell wrapper steps
  around a command pattern, and the config keys used here are `read: allow`
  and `external_directory: deny`. `docs/how-it-works.md` records Claude
  Code's permissions page as read on 2026-10-18: the list matches command
  text and is not a security boundary.

Unverified, and not to be built on as if they were measured:

- That an item created with `-T ""` raises a system dialog on every read,
  and that a process cannot answer that dialog. The man page says the
  trusted case is access without warning. It does not describe the warning,
  and it does not say a terminal can or cannot click it. The default
  partition list is not in the page, so it is also unverified whether
  `security` can still read the item in silence after `-T ""`.
- Whether a trailing `-w` accepts the password on standard input, or only
  from a terminal prompt.
- The largest value a generic password item holds.
- Linux `secret-tool` and libsecret. `command -v secret-tool` on this Mac
  on 2026-10-31 found nothing, and there is no local man page. Attribute
  names, the prompt, and what happens with no Secret Service daemon are all
  unverified.
- Windows DPAPI. This Mac has no local page for it. Whether a same-user
  process decrypts the file without a prompt is unverified. Question 6
  assumes that is the risk and does not state it as fact.
- Claude Code's `Read` rule syntax and whether a `deny` beats `Bash(just:*)`
  on Claude. The strings above are the ones grok 1.0.62 documents as the
  `.claude/settings.json` form. Spec 031 and `docs/agent-capabilities.md`
  (2026-10-19) still mark Claude's matcher unmeasured.
- Grok's `Read` deny and sandbox deny at run time. The pages above were
  read; n-5b9b58 records that the `Read` syntax was not measured, and
  n-fc65ca records that the wrapper bypass was not measured on grok.
- opencode's rule for denying one path inside the project. Not in spec 038's
  measurement, and not in the 2.2.3 cellar files listed on 2026-10-31.
- The credential paths of Claude, opencode, Kimi, and gh. gh's `hosts.yml`
  and `~/.appstoreconnect/config.env` are names from the 2026-10-31
  measurement, not from those tools' manuals (gh's manual was not opened).
