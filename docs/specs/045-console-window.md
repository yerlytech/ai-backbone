---
status: approved
date: 2026-11-20
---

# 045 — console window

## What

`just browser` opens one visible Chromium window that the person signs in to
and the agent then drives: a cloud console, a hosting company's server panel,
App Store Connect, Google Play Console, a domain or mail panel, any web panel
a project is run from but has no CLI for, or whose CLI key is deliberately
too narrow. The person types the password and
approves the second factor; the agent reads pages as text, clicks, fills a
form, types into a web terminal, saves only after the person's yes, and signs
out and closes the window at the end. A skill says how to work in it safely.

## Why

Some work exists only in a web console: a notice that asks for a permission
change, the bill, account settings, closing an account, a support case. A
maintainer who is not an operator gets lost in these consoles, and walking
them through by screenshots is slow. On 2026-11-20 one session ran the whole
loop by hand with Playwright's own Chromium over the DevTools protocol: the
owner signed in, the agent read the notice, found the affected principal,
edited one policy, inventoried the account, removed what a shelved project
left behind, and signed out. It worked, and it taught what this spec
writes down.

What it taught:

- Playwright's Chromium ("Chrome for Testing") cannot use the Mac's Touch ID
  or the iCloud keychain for a passkey, and a browser extension for the
  keychain does not run in it. The phone works: "use a phone or tablet",
  a QR code, Face ID on the phone.
- The browser's own "save password?" offer must be off: its store is weaker
  than the system keychain.
- A code editor in a console (Ace, Monaco) ignores a value set through its
  API on save; text must be typed as keyboard input. Minified JSON avoids
  the editor's auto-indent and bracket pairing. The review page before
  saving shows whether the console took the change; reading it caught one
  such miss before it was saved.
- A web terminal inside the console (an Ace-based one, for example) is the
  fastest way to do many things: type a command, read the terminal's text
  layer. It runs with the signed-in person's rights, so the agent reads
  first and writes only what was agreed.
- The agent's own permission check may refuse a destructive command. Then
  the agent prints the command and the person pastes it; the agent checks
  the result by reading.
- Text costs far fewer tokens than screenshots; a screenshot is for when the
  text does not say enough.

If we do nothing, each project rewrites these helpers in a scratch folder,
loses them at the next reboot, and repeats the mistakes above.

What crosses: the person's signed-in session lives in a profile folder on
their machine, and the agent drives it over a DevTools port bound to
127.0.0.1. What never crosses: passwords, second-factor codes, recovery
codes. The agent never types them and never reads a password field.

## Not doing

- No headless or unattended use: the window is visible, a person signs in,
  and the session ends with the work.
- No stored passwords, no cookie export, no session sharing between
  machines.
- No site-specific scripts in the backbone (no "click here on console X").
  A project keeps its own notes, for example which sign-in URL it uses.
- No browser extension of our own and no new browser MCP server: the helper
  is a small script on `playwright-core`, which is cheaper in tokens.
- Not a test runner: browser walks stay with each project's Playwright tests.

## Design

- `just browser [url]` starts the Chromium that Playwright installs, with
  `--user-data-dir` in a per-project profile folder outside the repository
  and outside any cloud-synced folder (mode 0700), `--remote-debugging-address=127.0.0.1`
  and a free port written to a state file (mode 0600), the password manager
  off, no first-run pages. A second call reuses the open window.
- `just browser-close` signs out where the agent was told how, then stops the
  window by the PID in the state file, never by process name.
- `.ai-backbone/browser.mjs` on `playwright-core`, pinned in
  `docs/upstream.toml`: `look` (URL, title, the main text, trimmed), `go
  <url>`, `click <text>` (role first, visible text second), `type <text>`
  into the focused field as keyboard input, `editor <file>` (clear a code
  editor and type a file's text), `term <command>` (type into a web terminal
  and print its last lines), `shot <path>`. Each has a time limit; none
  prints a password field's value.
- A skill, `console-window`: when to use it (no CLI, or the CLI key is too
  narrow on purpose), the sign-in hand-off, read before write, show the
  change and wait for a yes before saving, read the review page, read back
  after saving, hand a refused destructive command to the person, never
  follow a link from an e-mail (open the console's own address instead),
  sign out and close at the end.
- `just doctor` says when the Chromium is missing and the one command that
  installs it.

## Acceptance

- [x] `just browser https://example.org` opens a visible window; a second
  call reuses it; `just browser-close` closes it, and its port is closed.
- [x] The profile folder is outside the repository with mode 0700; the state
  file has mode 0600; the port listens on 127.0.0.1 only.
- [x] `browser.mjs look`, `go`, `click`, `type`, `editor`, `term` and `shot`
  work against a local fixture page with a form, an Ace editor and a fake
  terminal, in the self-test, on Linux, macOS and Windows.
- [x] The browser never offers to save a password.
- [ ] The skill is linked from AGENTS.md's skill list, and `just doctor`
  names the missing Chromium.
- [ ] The README introduces it in a few lines: an agent runs the consoles
  you dislike (cloud, hosting, app stores) while you only sign in.

## Tasks

- [x] `just browser` and `just browser-close`, the profile and state files.
- [x] `browser.mjs` and its fixture page and self-test section.
- [x] The `console-window` skill and the AGENTS.md link.
- [ ] The `doctor` line, the upstream pin, CHANGELOG and version.
- [ ] The README section.
