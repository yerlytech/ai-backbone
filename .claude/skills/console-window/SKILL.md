---
name: console-window
description: Run a signed-in web console through the project's visible Chromium window. Use when a cloud, hosting, domain, mail, App Store Connect or Google Play Console task has no CLI, or its CLI key is deliberately too narrow; the person signs in and approves every save.
---

# Console window

Use this for a web panel that has no suitable CLI. Do not use it for headless or
unattended work, cookie export, session sharing, or storing passwords. Keep
site-specific addresses and notes in the project, not in the backbone.

## Open and sign in

1. Open the console's own address: `just browser <url>`. Never follow a sign-in
   link from an e-mail. A second `just browser` reuses the same window.
2. Hand the window to the person. They type every password, second-factor code
   and recovery code. The agent never reads or types those values.
3. Playwright's Chromium cannot use the Mac's Touch ID or iCloud keychain for a
   passkey. Choose "use a phone or tablet" and let the person scan the QR code
   and approve on the phone.
4. The browser's password-save offer is deliberately off. Do not turn it on.

If Chromium is missing, `just doctor` prints the one pinned install command.

## Read, then change

Prefer text over screenshots: `just _browser look` prints the URL, title and
trimmed main text. Use `just _browser shot <path>` only when the text does not
say enough.

Commands:

- `just _browser go <url>` opens a known address in the current page.
- `just _browser click <text>` tries a matching role, then visible text.
- Click a field or its label, then `just _browser type <text>` to use keyboard
  input in the focused field. The helper refuses a password field.
- Click a code editor, then `just _browser editor <file>`. It selects and clears
  the old text, types the file, and prints the editor's text layer. JSON is
  minified first to avoid auto-indent and bracket pairing. Do not merely set an
  editor's value through its API: the console may ignore that value on save.
- Click a web terminal, then `just _browser term <command>`. It types the
  command, waits, and prints the terminal's last lines. The terminal has the
  signed-in person's rights: read first and write only what was agreed.

Before any save, show the person exactly what will change and wait for their
yes. Read the console's review page before saving; it can reveal that an editor
did not take the change. Read the result back after saving.

If the agent's permission check refuses a destructive command, stop trying to
run it. Print the command for the person to paste, then read the result. Do not
weaken the permission check or look for another way around it.

## Finish

Sign out using the console's own command when the project has said how, then run
`just browser-close`. This stops the saved browser PID; it never kills browsers
by name. Leave no signed-in console window behind when the work is done.
