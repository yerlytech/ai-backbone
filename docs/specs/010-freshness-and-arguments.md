---
status: done
date: 2026-09-19
---

# 010 — 3.20.0: what you type is what runs, and what you know ends on a date

## What

One backbone version, 3.20.0, built from the six research areas after their
skeptics. When it is done:

- Every recipe that takes a word from a person reads it as `$1` under
  `[positional-arguments]`; nothing typed is ever pasted into a script again,
  and the self-test refuses a recipe that goes back to pasting — in
  `core.just`, the backbone's own `Justfile` and the stack examples.
- `setup.sh` asks uv twice, both answers on the screen, ends with a sentence
  that is true, and names the just floor (1.29.0) before an old just stops at
  "unknown attribute" — and moves that just itself. `just tools-update` moves a
  just that uv installed.
- `just upstream` counts a source it could not read, prints why, stops calling
  a monorepo's sub-package tag "newer", ships an example row that is true on
  day one, runs on the Python uv already keeps, and shows each pin's own
  release date. `just upstream <name>` lists where the pinned version itself
  can be read on this machine. `just session-start` prints, every session and
  offline, what the project is built on and which pins came out in the last
  twelve months.
- The rule the maintainer asked for is written where every project reads it:
  what an agent knows ends on a date, so a pinned version is read or measured,
  never remembered, and the ADR says what it was measured on.
- `just template-update` survives a jump of many versions and says when a
  CHANGELOG entry names `AGENTS.md`, the seed file no update carries.
- `just ci` says, in GitHub's words, why a job never started.
- The Rust example is true for a workspace at the root and ships `fmt` and
  `test-fast`, which Yerly XL wrote by hand.

Nothing a person types changes. No new dependency. No new duty.

## Why

Five open backlog lines and one request from the maintainer, each with a real
cost behind it:

- `just save 'fix: pay $amount'` dies with "unbound variable" and
  `just save 'fix: $(touch X)'` creates X — reproduced by three agents on the
  unfixed backbone (report just-args, finding 1; both skeptics). Twenty-one
  recipes in `core.just`, one in the root `Justfile` and one in the Swift
  example have the same hole.
- A Linux sandbox's `setup.sh -y` ended with "just could not be installed" and
  told the reader to type the line that had just failed; the same line typed
  by hand a moment later worked (backlog 2026-09-18). Nothing declared the just
  floor, and Ubuntu 24.04's package (1.21.0) fails to parse `core.just` with no
  hint (Launchpad: `just 1.21.0-1 in noble amd64`).
- `just upstream` said "Everything watched is current." while all four sources
  were 403 behind a proxy (backlog 2026-09-18): `upstream.py:183` puts the word
  in the `newest` column and `:224` reads the `how` column. Yerly XL's a2ui row
  reads "2 newer" every week because the 2 in `a2ui` parses as a version; a
  fresh list's example row is MOVED on day one; and on a Mac whose python3 is
  Apple's 3.9 the script dies at `import tomllib` behind `2>/dev/null || true`.
- An agent's training ends on a day; a version released after it is one the
  agent will not know and will not say so. Yerly XL made "measured, on
  SurrealDB 3.2.4" its habit by hand (ADR 0017 l.20, ADR 0014 l.119) and the
  maintainer asked for the habit to be the rule.
- A rule added to the seed `AGENTS.md` reaches no existing project, and the one
  recipe that could say so — `just template-update` — dies with exit 141 after
  copying the files once the span it prints outgrows the pipe buffer (10 of 10
  runs from 3.5.0; certain above ~400 CHANGELOG lines). On the daily
  `just projects-update` that leaves a project half-updated and skipped as
  "unsaved work" every day after.
- Twelve of Yerly XL's pushes were red for a day on 2026-09-18 while `just ci`
  said "GitHub keeps no log for that job"; the reason was a billing hold,
  written in the job's annotations and found by hand.

## Not doing

Dropped, with the refutation that dropped it:

- **A global `set positional-arguments`.** It reaches every recipe in the
  project and is a hard error when the project's Justfile sets it too
  (`error: setting positional-arguments first set on line 1 is redefined`).
  Exported `$msg` parameters (they change what `just --list` shows) and
  `{{quote(msg)}}` (breaks the moment somebody adds the quotes every other line
  has) were tried and rejected.
- **A just-version or python3 line in `just doctor`.** Doctor lives in the file
  an old just cannot parse, so it would only run where it is not needed; the
  python3 line pointed a non-programmer at `brew install python`, a global
  install the backbone does not ask for, while uv already owns a Python ≥3.11
  on every machine that ran `setup.sh` (`uv python find '>=3.11'
  --no-python-downloads` answers in 0.006 s). Refuted by the fits skeptic;
  the fix (a hidden `_py` recipe) is in.
- **`set minimum-version`.** On every just before 1.55.0 the setting is itself
  the first error (`Unknown setting minimum-version` on the 1.40.0 wheel), so
  it would break Debian stable, which works today.
- **A quiet first attempt in `setup.sh` (`uv_tool` helper).** It swallowed uv's
  own `warning: <dir> is not on your PATH`, which is the backlog note's second
  suspect, and the ending then pointed at nothing. Refuted by the fits skeptic;
  both attempts are live instead.
- **The XDG PATH chain in `setup.sh` (setup-sh P2).** No evidence a sandbox sets
  those variables; its own check could not pass; refuted by both skeptics.
- **`_lint-if-any` running `just test-fast` (ideas P5, hook half).** Reverses
  spec 009's "a commit must stay cheap" without a spec, makes the hook say
  `just lint … Failed` when lint passed, and doubles Yerly XL's own `test-fast`
  hook — a manual step, which the SemVer rule calls major. If wanted, it is a
  spec of its own that names 009 as amended. The example half ships.
- **The awk "Built on:" block in `session-start` (ideas P4).** Reads a TOML
  literal string as empty and a `pin =` inside a multi-line `check` as a row,
  and its checks reached GitHub. Folded into `upstream.py --recent`, which
  reads the list with tomllib.
- **A `just doctor` that diffs a project's `AGENTS.md` against the seed.**
  Projects rewrite the seed on purpose; a diff would nag a person.
- **A pre-push hook or a `just test` hook.** A gate before the push cannot keep
  a red commit local — the next green save pushes HEAD and everything under it —
  and spec 009 keeps a commit cheap. The 2026-09-17 line is ticked with that
  reason.
- **A `docs/README.md` row saying every ADR states what it was measured on.**
  That page describes the backbone's own two ADRs, which carry neither line.
- **Dropping `[group]` to lower the floor to 1.21.** A refactor of working
  code; the grouped `--list` is what a person sees.
- **Quoting `{{server_dir}}`/`{{games_dir}}` in the examples.** File-level
  variables the author sets; nobody's typed text reaches them.
- **prek changes** (`prepare-hooks`, `gitleaks-system`, `check-jsonc`, cooldown
  days) and **bumping pins for their own sake**: nothing to do; every tool the
  backbone relies on is at its latest release and `tools-update` moves graphify.
- **A `bin = "..."` key, `uv run --python` downloads, jq, a sidecar text file,
  a non-zero exit from `just upstream`, dating every tag of a tags-only
  project, a `docs` default for GitHub/npm** — rejected in the upstream-py
  report for the reasons given there; none re-argued.
- **Showing the push's stderr in `just save`.** Changes a message a person
  reads; would be a question, and nobody asked for it.

## Questions

None. Nothing here changes what the maintainer types or must do by hand: the
one rule that reaches existing projects by hand (`AGENTS.md` §8) is the agent's
job, as in 3.6.0, and `template-update` now says so; an old just is moved by
`setup.sh`, which the routine already runs first.

## Acceptance

Walked line by line on 2026-09-19, by the review's acceptance lens and again at
the release; read each line with the Addenda at the end, which override it.

- [x] In a fresh project, `just save 'fix: pay $amount'`, `just save 'fix: $(touch X)'`,
      ``just save 'fix: run `ls` first'`` and `just yedekle …` each commit the
      message verbatim and X never exists; the same for `just backbone-note`,
      `just spec 'Pay $amount'` and `just adr`. The suite's guard prints every
      recipe that takes a parameter without `[positional-arguments]` and every
      `{{param}}` left in a body, across `core.just`, `Justfile` and
      `examples/stack-*.just`; it prints nothing.
- [x] With every tool faked, `setup.sh -y`: installs nothing when all are present;
      asks uv once more after one refusal; after two refusals shows both answers
      and ends "just is not on the PATH. What the installer said above …"; with a
      just shim at 1.20.0 and uname Linux it says the version and the path, runs
      `uv tool install rust-just`, and goes on to doctor; when uv keeps refusing
      it exits 1 naming the version and path. `sh -n`, `dash -n` and `bash -n`
      pass.
- [x] `just tools-update` with a fake uv that lists `rust-just` prints
      `Upgraded rust-just`; with a list that does not, no rust-just line.
- [x] `AI_BACKBONE_OFFLINE=1 just upstream` in a fresh project prints
      `UNKNOWN: example`, its reason, `Everything readable is current. Could not
      read: example.`, and never `MOVED`. `parts("python/a2ui-core/v0.1.1") <
      parts("v0.9")`. `env PATH=/usr/bin:/bin:$PATH just upstream` runs on a Mac.
- [x] `just upstream` shows a `released` column; `just upstream <name>` prints
      `released <date>` and the where-list (docs, pinned in, source folders,
      notes, on PATH). `just session-start` prints `Built on: …` and either the
      pins released in the last twelve months with the fixed sentence, or
      "not known yet … when the sources can be reached"; nothing without a list.
- [x] `just template-update` from a core.just marked 3.5.0 exits 0, prints
      "… and N more lines", the two `AGENTS.md` reminder lines and the `Next:`
      line; a second run says "Already up to date".
- [x] `just _ci-why < fixture` prints "The job was not started because …";
      a notice-only array and empty input print nothing, exit 0; the fixture
      carries no repository name or commit of the maintainer's.
- [x] `just --evaluate server_dir` from the Rust example is `.` beside a root
      `Cargo.toml` and `server` otherwise; `fmt` and `test-fast` are listed.
- [x] The session skill, `AGENTS.md` §8, the spec skill, the ADR template and
      the first audit lens carry the rule texts below; `just adr` output keeps
      the Measured-on line; `just sync-rules` regenerates the copies.
- [x] CHANGELOG entry 3.20.0, `core.just` says 3.20.0, self-test green, the
      four backlog lines ticked and the ci-swift line annotated.

## Tasks

One commit each, smallest first. `docs/README.md` needs no change in any of
them (it does not describe setup, upstream or argument handling; two agents
grepped it). Every check is written for the suite's `check`/`says` helpers and
none pipes a command into grep.

### 1. Tick the publish-on-save line

Files: `docs/backlog.md`. The tick text is under **Backlog ticks** below. No
checks, no docs.

### 2. The Rust example as the first project rewrote it

Files: `.ai-backbone/examples/stack-rust.just`, `.ai-backbone/examples/README.md`,
`.ai-backbone/self-test.sh`.

- Header: `# stack-rust.just — Rust and Cargo; the database group is sqlx and
  PostgreSQL, delete it on another database`, with the sentence that the first
  project runs SurrealDB with its workspace at the root and rewrote this header.
- `server_dir := if path_exists("Cargo.toml") == "true" { "." } else { "server" }`
  (just resolves it against the Justfile's directory; proven from a
  subdirectory too).
- `fmt:` (`cargo fmt --all`, with the why: a contributor lost an hour to
  `cargo fmt -p` printing help) and `test-fast:` (`cargo test --workspace --lib
  --bins --tests`, with the why and the numbers 9 s against 37 s; the comment
  says a project that wants it before every commit adds `entry: just test-fast`
  to its own `.pre-commit-config.yaml`, as Yerly XL did — the hook is not
  changed here, see Not doing).
- `# sqlx and PostgreSQL. On another database, delete this group.` above the
  database group.

Checks, in "== a project without a language ==" before "== checks on every push ==":

```
# The Rust example must be true for a workspace at the root as well as in server/ (3.20.0).
for d in ws nows; do mkdir -p "$tmp/$d"; printf "import? 'stack.just'\n" > "$tmp/$d/Justfile"; cp "$root/.ai-backbone/examples/stack-rust.just" "$tmp/$d/stack.just"; done; touch "$tmp/ws/Cargo.toml"
check "stack rust finds a workspace at the root"      "says '^\.$' sh -c \"cd '$tmp/ws' && just --evaluate server_dir\""
check "stack rust assumes server/ otherwise"          "says '^server$' sh -c \"cd '$tmp/nows' && just --evaluate server_dir\""
check "stack rust ships fmt and test-fast"            "says 'fmt' sh -c \"cd '$tmp/nows' && just --summary\" && says 'test-fast' sh -c \"cd '$tmp/nows' && just --summary\""
```

Docs: `examples/README.md` table row for `stack-rust.just`: "Rust and Cargo;
a sqlx/PostgreSQL group you can delete; `server_dir` finds a root workspace".

### 3. `just ci` says why a job never started

Files: `.ai-backbone/core.just` (`ci`, new `_ci-why`), new
`.ai-backbone/fixtures/gh-annotations-not-started.json`, `.ai-backbone/manifest.txt`,
`.ai-backbone/self-test.sh`, `docs/01-getting-started.md`.

- In `ci`'s second loop, add `[ "$failstep" = "-" ] && failstep=""` as its
  second line (the first loop normalises; the second read `-` raw, so the
  annotation was never asked for — the works skeptic's shim run proved the
  fix: two annotation calls, "The job never started. GitHub's reason: …").
- When the log is empty and `$failstep` is empty:
  `why=$(gh api "repos/{owner}/{repo}/check-runs/$jid/annotations" 2>/dev/null | just _ci-why)`;
  print `    The job never started. GitHub's reason: $why` when non-empty, else
  the existing "keeps no log" line.
- `_ci-why`: bash, `set -uo pipefail`, python3 reading the annotations JSON on
  stdin, printing the first `failure` annotation's message up to its first
  `. `; the python invocation ends `|| true` so empty input is silent, exit 0.
  Any python3 will do (json only).
- Fixture: the real answer for job 105582391463, with `blob_href` scrubbed to
  `https://github.com/example/repo/blob/0000000/.github` (the original carries
  `yerlytech/xlarge` and a commit SHA; AGENTS.md §7). Listed in `manifest.txt`
  under `[backbone]` next to `gh-log-failed.txt`.

Checks, in "== checks on every push ==" beside the `_ci-lines` checks:

```
# A job that never ran has no log; GitHub puts the reason in its annotations (3.20.0).
check "ci names why a job never started"              "says 'was not started because' just _ci-why < '$root/.ai-backbone/fixtures/gh-annotations-not-started.json'"
check "ci-why is silent for a job that ran"           "[ -z \"\$(printf '[{\"annotation_level\":\"notice\",\"message\":\"x\"}]' | just _ci-why)\" ]"
check "and calm on nothing at all"                    "printf '' | just _ci-why"
```

Docs: `docs/01-getting-started.md` §5b, the `just ci` paragraph: "…no address,
still running, and a job that never started, with GitHub's reason."

### 4. `template-update` survives a long span and says when the rules gained a line

Files: `.ai-backbone/core.just` (`template-update`), `.ai-backbone/self-test.sh`,
`.agents/skills/backbone-update/SKILL.md`, `docs/01-getting-started.md`.

- Capture the CHANGELOG span with `slice=$(awk …)`, print `awk 'NR<=60'
  <<<"$slice"`, then `… and $((total-60)) more lines in .ai-backbone/CHANGELOG.md`
  (count with `printf '%s\n' "$slice" | …` no — count as `awk 'END{print NR}'
  <<<"$slice"`; the trailing blank line is stripped by `$(…)`, so the number is
  one short of `wc`; acceptable, or add one when the file's span ended blank).
- Recipe comment, corrected per the works skeptic: "a pipe into `head` here is
  a SIGPIPE under pipefail once the span outgrows the pipe buffer — about 400
  CHANGELOG lines, ten versions, today — and a project that skipped that many
  died with exit 141 after copying the files."
- `if grep -q 'AGENTS\.md' <<<"$slice"` → the two reminder lines (text under
  **Rule texts**).

Checks, in "== a new project ==" directly before the existing
"hook config is the project's" check (which needs "Already up to date"):

```
# A jump of many versions used to die with exit 141 after copying the files, and a
# rule the seed AGENTS.md gained reached no existing project unless somebody read the
# changelog (3.20.0). 3.5.0 is planted because the 3.6.0 entry names AGENTS.md.
check "template-update survives a span of many versions"  "perl -pi -e 's/version [0-9.]+/version 3.5.0/ if \$.==1' .ai-backbone/core.just && says '^Next: just sync-rules' just template-update"
check "template-update says when the rules gained a line the seed will not carry"  "perl -pi -e 's/version [0-9.]+/version 3.5.0/ if \$.==1' .ai-backbone/core.just && says 'names AGENTS.md' just template-update"
check "and is quiet once nothing is behind"           "says 'Already up to date' just template-update"
```

Docs: backbone-update skill step 3 gains "At the end it prints the CHANGELOG
entries between the old and the new version, and says when one of them names
`AGENTS.md`." `docs/01-getting-started.md` "Keeping things fresh", the
`just template-update` line: "pull it: only its own files, zip copy first,
prints what changed and says when the rules gained a line only your agent can
add".

### 5. A recipe reads its arguments as `$1`, never as `{{arg}}`

Files: `.ai-backbone/core.just` (21 recipes + header), `Justfile` (root,
`projects-update-schedule`), `.ai-backbone/examples/stack-swift.just`
(`build-app`), `.ai-backbone/examples/README.md`, `.ai-backbone/self-test.sh`,
`.agents/skills/backbone-dev/SKILL.md`, `docs/backlog.md` (tick, line 25).

- `[positional-arguments]` on the line directly above each header that takes a
  parameter (below its `[group(...)]` line where it has one): ci-init, stack,
  spec, adr, save, publish-on-save, ci, archive, routine-install, upstream,
  new-project, adopt, ref-add, backbone-note, `_msg`, `_backbone-refresh`,
  `_backbone-tag`, `_manifest`, `_commit-msg-check`, `_slug`, `_stamp-brain-lang`;
  plus `projects-update-schedule` in the root `Justfile` and `build-app` in
  `stack-swift.just`.
- Every `{{param}}` in a body becomes `"$1"`/`"$2"` (the report's diff, hunk
  by hunk; regenerate it from the researcher's `fixed/` files with `diff -u`
  rather than pasting the report's text, whose `_stamp-brain-lang` hunk header
  is miscounted). `spec`/`adr` print the name with `printf '%s\n'`; `upstream`
  passes `${1:+"$1"}`; `_manifest` reads `-v s="[$2]" … "$1"`; `_slug` is
  `@printf '%s' "$1" | perl …`.
- Header lines in `core.just` after line 4 (text under **Rule texts**).
- Self-test header gains one sentence after the SIGPIPE note: "The recipes run
  under /bin/bash 3.2 on every Mac and bash 5 on CI; a line that passes on one
  can fail on the other, so a check runs the line rather than reading it."

Checks. In "== the suite itself ==" after the pipe guard:

```
# A recipe that takes a parameter reads it as $1 and never writes {{param}} into its
# script: text spliced into a script runs (3.20.0). The attribute sits on the line
# directly above the header. Prints every offence; empty when clean.
spliced() {
  awk '
    /^[A-Za-z_][A-Za-z0-9_-]*( [+*$]?[A-Za-z_][A-Za-z0-9_-]*(=("[^"]*"|[^ ]+))?)+:/ {
      name=$1; n=split($0, w, " "); np=0
      for (i=2; i<=n; i++) { p=w[i]; sub(/[=:].*/, "", p); sub(/^[+*$]+/, "", p); if (p ~ /^[A-Za-z_]/) params[++np]=p }
      if (prev !~ /positional-arguments/) print FILENAME ":" FNR ": " name " takes a parameter without [positional-arguments]"
      body=1; prev=$0; next }
    /^[^ \t]/ { body=0 }
    body { for (i=1; i<=np; i++) if ($0 ~ ("\\{\\{ *" params[i] " *\\}\\}")) print FILENAME ":" FNR ": " name " splices {{" params[i] "}}" }
    { prev=$0 }
  ' "$root/.ai-backbone/core.just" "$root/Justfile" "$root"/.ai-backbone/examples/stack-*.just
}
check "no recipe splices a parameter into its script"  "! says . spliced"
```

In "== a new project ==" after "plain save message gets chore:" (the Turkish
project, so `yedekle` exists):

```
# Free text reaches a recipe's script as an argument, never as text spliced into it
# (3.20.0): a dollar sign stays a dollar sign, a dollar-paren runs nothing, quotes and
# backticks arrive as typed. The file that must not exist is the important check.
echo x >> src/README.md
check "save keeps a dollar sign in the message"        "just save 'fix: pay \$amount' && says '^fix: pay \\\$amount\$' git log -1 --format=%s"
echo x >> src/README.md
check "save runs nothing a message asks it to"         "just save 'fix: \$(touch $tmp/PWNED)' && [ ! -e '$tmp/PWNED' ] && says '^fix: \\\$\\(touch ' git log -1 --format=%s"
echo x >> src/README.md
check "save keeps quotes and backticks as typed"       "just save 'fix: say \"hi\" and run \`ls\`' && [ \"\$(git log -1 --format=%s)\" = 'fix: say \"hi\" and run \`ls\`' ]"
echo x >> src/README.md
check "yedekle passes the message through untouched"   "just yedekle 'fix: pay \$amount again' && says '^fix: pay \\\$amount again\$' git log -1 --format=%s"
check "spec name with a dollar sign becomes a slug"    "just spec 'Pay \$amount' && compgen -G 'docs/specs/*-pay-amount.md' && grep -q '— Pay \\\$amount\$' docs/specs/*-pay-amount.md"
```

After "backbone-note saves the note in the backbone by itself":

```
check "backbone-note runs nothing a note asks it to"   "AI_BACKBONE='$tmp/bb' just backbone-note '\$(touch $tmp/PWNED2)' && [ ! -e '$tmp/PWNED2' ] && grep -qF ': \$(touch $tmp/PWNED2)' '$tmp/bb/docs/backlog.md'"
```

(All seven passed verbatim inside the full suite on a patched copy named
`ai-backbone`: 101 ok; on the unpatched backbone the seven are red.)

Docs: none in `docs/` — no command a person types changes. The rule goes in
`core.just`'s header (project class, the file an agent copies from), the
backbone-dev skill (project class, refreshed everywhere) and `examples/README.md`
(text under **Rule texts**).

### 6. `setup.sh` asks uv twice, shows both answers, ends with a true sentence

Files: `.ai-backbone/setup.sh`, `.ai-backbone/self-test.sh`, `.ai-backbone/routine.md`,
`.ai-backbone/templates/routine-project.md`, `docs/01-getting-started.md`,
`docs/backlog.md` (tick, line 24).

- Lines 38, 43, 44: `uv tool install X || uv tool install X` (no helper, no
  captured variable; uv's own words, including `warning: <dir> is not on your
  PATH`, stay on the screen).
- Ending: keep `if need just; then just doctor`; delete the "installed but not
  on the PATH yet" branch (never true for anything this script installs: the
  exports precede the ending, and `brew shellenv` runs only on Darwin); `else`
  prints the two lines under **Rule texts**. Comment above it says "`brew
  shellenv` above", no line number.

Checks, a new section after "== the suite itself ==":

```
echo "== setup.sh =="
# Run with every tool faked, so nothing real is installed. `uname` says Linux so
# the uv branch runs on every machine; HOME is an empty folder and the PATH holds
# only the fakes and the system, so no real tool can shadow a fake; `uv` counts
# its `tool install` calls in a file, refuses the first UV_FAILS of them, then
# plants the tool in ~/.local/bin the way the real one does. The fake just
# answers --version, because the floor check below reads it.
f="$tmp/fakes"; mkdir -p "$f"
printf '#!/bin/sh\necho Linux\n' > "$f/uname"
for t in prek graphify gh; do printf '#!/bin/sh\necho "fake %s $*"\n' "$t" > "$f/$t"; done
printf '#!/bin/sh\ncase "$1" in --version) echo "just ${FAKE_JUST:-1.58.0}" ;; *) echo "fake just $*" ;; esac\n' > "$f/just"
cat > "$f/uv" <<'EOF'
#!/bin/sh
[ "$1 $2" = "tool install" ] || exit 0
n=$(( $(cat "$UV_COUNT" 2>/dev/null || echo 0) + 1 )); echo "$n" > "$UV_COUNT"
[ "$n" -le "$UV_FAILS" ] && { echo "error: fake uv refused (attempt $n)" >&2; exit 1; }
case "$3" in rust-just) b=just ;; graphifyy) b=graphify ;; *) b=$3 ;; esac
mkdir -p "$HOME/.local/bin"; printf '#!/bin/sh\ncase "$1" in --version) echo "just 1.58.0" ;; *) echo "fake %s $*" ;; esac\n' "$b" > "$HOME/.local/bin/$b"; chmod +x "$HOME/.local/bin/$b"
EOF
chmod +x "$f"/*
setup() { rm -rf "$tmp/home" "$tmp/uv-count"; mkdir -p "$tmp/home"; HOME="$tmp/home" PATH="$f:/usr/bin:/bin" UV_COUNT="$tmp/uv-count" UV_FAILS="$1" sh "$root/.ai-backbone/setup.sh" -y; }
calls() { cat "$tmp/uv-count" 2>/dev/null || echo 0; }
# The output is reused across checks, so `says` is not used here; the herestrings
# read a variable, not a pipe.
check "setup.sh parses under dash where there is one"  "! command -v dash >/dev/null || dash -n '$root/.ai-backbone/setup.sh'"
out=$(setup 0 2>&1)
check "with every tool present, setup.sh installs nothing and ends in doctor" "[ \$(calls) = 0 ] && ! grep -q '^-> ' <<<\"\$out\" && grep -q 'fake just doctor' <<<\"\$out\""
rm -f "$f/just"
out=$(setup 1 2>&1)
check "a tool uv refuses once is asked for once more"  "[ \$(calls) = 2 ] && grep -q 'fake just doctor' <<<\"\$out\""
out=$(setup 9 2>&1)
check "refused twice: no third try, and both answers are shown" "[ \$(calls) = 2 ] && grep -q 'refused (attempt 1)' <<<\"\$out\" && grep -q 'refused (attempt 2)' <<<\"\$out\""
check "and the ending points at them instead of a command to retype" "grep -q 'is not on the PATH' <<<\"\$out\" && ! grep -q 'Install it by hand' <<<\"\$out\""
```

Docs: `docs/01-getting-started.md` §1 after "Afterwards, and any time later,
`just doctor` says what is missing.": "If a tool cannot be installed, the script
tries once more, shows what the installer answered, and asks you to run it again
once that is fixed." `routine.md` step 1 and `templates/routine-project.md`
step 1: text under **Rule texts**.

### 7. The just floor (1.29.0), said before an old just reads a recipe

Files: `.ai-backbone/setup.sh`, `.ai-backbone/core.just` (header, `tools-update`),
`.ai-backbone/self-test.sh`, `.github/workflows/checks.yml`,
`docs/01-getting-started.md`, `docs/upstream.toml`, `.ai-backbone/routine.md`,
`.ai-backbone/templates/routine-project.md`.

- In `setup.sh`, directly after line 42's `export PATH=…` and before `need prek`
  (so no installer runs before the floor is judged, and the suite's run calls
  no real uv):

```sh
# The recipes need just 1.29.0 or newer (the [positional-arguments] attribute;
# the seed Justfile's `import?` needs 1.21.0). A distro package can be older —
# Ubuntu 24.04 ships 1.21.0 — and it stops at "unknown attribute" without saying
# why. Said here, before just reads a single recipe, and moved here too.
need_just=1.29.0
ver_ge() { [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -1)" = "$2" ]; }
have_just() { just --version 2>/dev/null | awk '{print $2}'; }
v=$(have_just)
if need just && ! ver_ge "$v" "$need_just"; then
  echo "-> just $v at $(command -v just) is older than $need_just, which the recipes need"
  if [ "$os" = Darwin ]; then brew upgrade just; else uv tool install rust-just; fi
  hash -r 2>/dev/null || true
  v=$(have_just)
  if ! ver_ge "$v" "$need_just"; then
    echo "just is still $v at $(command -v just); the recipes need $need_just or newer."
    echo "  Mac:   brew upgrade just        Linux:  uv tool install rust-just"
    exit 1
  fi
fi
```

  (`sort -V` is on macOS, dash and GNU coreutils; `ver_ge` was run under sh and
  dash for 1.58.0, 1.27.0, 1.21.0, 1.9.0, 1.100.0, 0.9.4 and empty. A
  uv-installed just is never below 1.35.0, so on a Mac the old one is brew's or
  hand-installed, and the path in the message says which.)
- `core.just` header: "Needs just 1.29.0 or newer (the `[positional-arguments]`
  attribute). setup.sh says so before an older just stops at 'unknown
  attribute'." (The words `version N` are not in it, so `template-check`'s grep
  is unaffected.)
- `tools-update`: after the two `uv tool upgrade` lines,
  `case "$(uv tool list 2>/dev/null)" in *rust-just*) uv tool upgrade rust-just 2>&1 | tail -1 ;; esac`
  with the comment "On Linux just came through uv (setup.sh: rust-just) and brew
  is not there to move it; a pinned install stays pinned, which is uv's rule."
  Recipe comment (what `just --list` prints): "Update the tools this repo relies
  on: prek, graphify, the hook versions, and a just that uv installed".
- `checks.yml` line 60: one comment line — "the floor check's exit 1 is swallowed
  here on purpose; the runner has no just of its own, so setup.sh installs the
  newest".

Checks, in "== setup.sh ==" after task 6's:

```
# The floor: a just older than 1.29.0 cannot parse core.just, so setup.sh is the one
# place that can say so, and it moves the just itself (3.20.0).
check "setup.sh's version compare orders like a person would"  "sh -c \"\$(sed -n '/^ver_ge()/p' '$root/.ai-backbone/setup.sh'); ver_ge 1.58.0 1.29.0 && ver_ge 1.29.0 1.29.0 && ! ver_ge 1.21.0 1.29.0 && ! ver_ge 1.9.0 1.29.0\""
check "the just floor in setup.sh is the one core.just names" "f=\$(sed -n 's/^need_just=//p' '$root/.ai-backbone/setup.sh'); [ -n \"\$f\" ] && [ \"\$f\" = \"\$(grep -m1 -oE 'Needs just [0-9.]+' '$root/.ai-backbone/core.just' | awk '{print \$3}')\" ]"
printf '#!/bin/sh\ncase "$1" in --version) echo "just 1.20.0" ;; *) echo "fake just $*" ;; esac\n' > "$f/just"; chmod +x "$f/just"
out=$(setup 0 2>&1)
check "setup.sh moves a just that is too old, and says which one" "grep -q 'just 1.20.0 at .* is older than 1.29.0' <<<\"\$out\" && [ \$(calls) = 1 ] && grep -q 'fake just doctor' <<<\"\$out\""
out=$(setup 9 2>&1); rc=$?
check "and stops, naming the version and the path, when it cannot" "[ \$rc -ne 0 ] && grep -q 'still 1.20.0 at' <<<\"\$out\" && ! grep -q 'fake just doctor' <<<\"\$out\""
rm -f "$f/just"
# tools-update on a Linux box: just came through uv and brew is not there. The PATH
# hides brew and prek, or the suite would upgrade this machine's tools on every core commit.
mkdir -p "$tmp/shim"; ln -sf "$(command -v just)" "$tmp/shim/just"
printf '#!/bin/sh\ncase "$1 $2" in "tool list") cat "$UV_FAKE_LIST" ;; "tool upgrade") echo "Upgraded $3" ;; esac\n' > "$tmp/shim/uv"; chmod +x "$tmp/shim/uv"
printf 'rust-just v1.58.0\n- just\n' > "$tmp/list-linux"; printf 'prek v0.5.3\n- prek\n' > "$tmp/list-mac"
check "tools-update moves a just that uv installed"   "says 'Upgraded rust-just' env UV_FAKE_LIST='$tmp/list-linux' PATH='$tmp/shim:/usr/bin:/bin' just -f '$root/Justfile' -d '$tmp/home' tools-update"
check "and leaves a brew just alone"                  "! says 'rust-just' env UV_FAKE_LIST='$tmp/list-mac' PATH='$tmp/shim:/usr/bin:/bin' just -f '$root/Justfile' -d '$tmp/home' tools-update"
```

(The two tools-update checks run in `$tmp/home`, an empty folder, so no
`.pre-commit-config.yaml` makes the recipe look for prek; if `-d` proves
awkward, run them later in `$tmp/plain` with `cd`.)

Docs: `docs/01-getting-started.md` §1 after the tool list: "The recipes need just
1.29.0 or newer. If the just already on the machine is older (Ubuntu 24.04's
package is 1.21.0), `setup.sh` says so and moves it." and the "Keeping things
fresh" `just tools-update` comment: "newer prek, graphify, hook versions, and
just where uv installed it". `docs/upstream.toml`, the just entry's `check`:
"…and whether the floor setup.sh names (1.29.0) is still the oldest just that
reads core.just". `routine.md` / `routine-project.md` step 1: "or is too old"
(text under **Rule texts**).

### 8. `just upstream` counts what it cannot read, and runs on the Python uv keeps

Files: `.ai-backbone/upstream.py`, `.ai-backbone/core.just` (`_py`, `upstream`,
`session-start`), `.ai-backbone/templates/upstream.toml`, `.ai-backbone/self-test.sh`,
`docs/01-getting-started.md`, `docs/backlog.md` (tick, line 23).

- `upstream.py`: `OFFLINE = bool(os.environ.get("AI_BACKBONE_OFFLINE"))`, and
  `look()` raises `Unreachable("offline: AI_BACKBONE_OFFLINE is set")` before any
  network; the exception row becomes
  `(name, pin, "?", "unreachable", pin_is_real(entry))` with the reason in a
  `why_not` map printed under the UNKNOWN line (70 chars); the last line reads
  "Everything readable is current. Could not read: …"; `just upstream <name>`
  looks the name up in the list first and says "the source could not be read:
  …" when it is silent; `pin_is_real` reads `entry.get("pin", "")` and an empty
  pin is `False`; `parts()` reads a tag's version from its last path segment
  (`rsplit("/", 1)[-1]`); the tomllib import moves into `main()` after the
  `--recent` branch (task 9), guarded: `Needs Python 3.11 or newer for tomllib;
  this is X. uv can put one here: uv python install 3.13`, exit 1.
- `core.just`: hidden `_py:` printing
  `uv python find '>=3.11' --no-project --no-python-downloads 2>/dev/null || command -v python3 || echo python3`;
  `upstream` runs `"$(just _py)" .ai-backbone/upstream.py ${1:+"$1"}`.
  `session-start`'s weekly line becomes
  `just upstream 2>/dev/null || echo "upstream: could not run -> just upstream"`,
  and both weekly blocks (backbone-news, upstream) are also skipped when
  `AI_BACKBONE_OFFLINE` is set, so the suite's never-reaches-GitHub promise no
  longer rests on two `touch` lines in one section.
- `templates/upstream.toml`: the example row watches
  `github:gitleaks/gitleaks`, pin `v8.30.1`, `pinned_in = ".pre-commit-config.yaml"`
  (the seed hook config holds that rev), `why = "checks every save for leaked
  secrets"`, `check = "what its rules now flag; run the hook over the whole tree
  once before following"`. Two legend lines: "a tool that lives as a binary and
  in no file has no pinned_in; MOVED cannot be said for it" and "check may be a
  multi-line string: check = \"\"\"…\"\"\"".
- `self-test.sh` line 11 comment: "never reach GitHub or a registry from a test".

Checks. Before "upstream is quiet until there is a list":

```
# upstream.py reads TOML with tomllib (Python 3.11); a Mac's own python3 is 3.9. The
# recipe asks uv for the Python it already keeps for prek and graphify (3.20.0).
check "upstream runs where python3 has no tomllib"    "says 'just upstream-init|watched' env PATH=/usr/bin:/bin:\$PATH just upstream"
```

After "upstream-init a second time changes nothing":

```
# The suite is offline, and upstream.py honours AI_BACKBONE_OFFLINE: every source
# counts as unreachable. Until 3.20.0 such a source was not counted at all and the
# last line said everything was current (backlog, 2026-09-18); and the example row
# was MOVED on day one, pinned to a file that never held it.
check "upstream names a source it could not read, and does not call it current" "says '^UNKNOWN: example' just upstream && ! says 'Everything watched is current' just upstream"
check "a fresh list's example row is true on day one"  "! says MOVED just upstream"
check "upstream <name> says where the pin lives even when its source is silent" "says 'pinned in +.pre-commit-config.yaml' just upstream example"
check "a monorepo tag is not newer than the pin"        "\"\$(just _py)\" -c 'import importlib.util as i; s=i.spec_from_file_location(\"u\", \".ai-backbone/upstream.py\"); u=i.module_from_spec(s); s.loader.exec_module(u); raise SystemExit(0 if u.parts(\"python/a2ui-core/v0.1.1\") < u.parts(\"v0.9\") < u.parts(\"v1.0\") else 1)'"
```

Docs: `docs/01-getting-started.md` "Keeping things fresh", the `just
upstream-init` line: "start the watch list, docs/upstream.toml; its example row
watches the secret scanner the hook config already pins".

### 9. Each pin's release date, where it lives on this machine, one offline line every session

Files: `.ai-backbone/upstream.py`, `.ai-backbone/core.just` (`session-start`),
`.ai-backbone/templates/upstream.toml`, `.agents/skills/session/SKILL.md`,
`.ai-backbone/self-test.sh`, `docs/01-getting-started.md`.

- `released_at(entry, releases)`: the release whose version equals the pin with a
  leading v stripped on both sides; a GitHub pin not among the fifty fetched costs
  one call per tag form to `releases/tags/<tag>`, then `commits/<tag>` for a
  tags-only repo; crates and npm lists are no longer cut at 50. A `released`
  column after `pinned`; `just upstream <name>` prints `released <date>` or
  `released: not known`.
- `where(entry)`: `docs` (an optional `docs = "url"` key; a crate defaults to
  `https://docs.rs/<crate>/<pin>`), `pinned in` (printed only when the pin is
  real; otherwise `listed in`), `source` for `~/.cargo/registry/src/*/<crate>-<pin>/`,
  `<dir of pinned_in>/node_modules/<pkg>/` (with "(holds X, not the pin)"),
  `uv tool dir/<name>/`, `notes` for any `CHANGELOG*` inside, `on PATH` with the
  binary's `--version` first line — every `subprocess.run` with `timeout=5` and
  `TimeoutExpired` caught. Printed under "where <pin> itself can be read on this
  machine:", or "(not found on this machine)".
- Cache gains `released: {name: {pin, at}}`; a date not obtained this run is kept
  from the previous cache when the pin is unchanged.
- `--recent`, network-free: reads the list with tomllib when the interpreter has
  it, else the cache's pins (so a Mac with only Apple's Python gets the line, not
  a nag); filters cached dates by the current list's names; prints the three
  lines under **Rule texts** (Built on / Released in the last 12 months /
  the sentence), or "not known yet … when the sources can be reached", or
  "none."; nothing without a list.
- `session-start`, after the weekly block:
  `if [ -f docs/upstream.toml ]; then echo; "$(just _py)" .ai-backbone/upstream.py --recent 2>/dev/null || true; fi`.
- `templates/upstream.toml` legend: `docs        optional: where that version's own documentation lives, a URL`.
- Session skill: Start step 1 gains "what the project is built on"; point 1 of
  "When something upstream has moved" gains "It also lists where the pinned
  version itself lives on this machine: the source folder, its changelog, the
  docs."

Checks, in "== checks on every push ==" right after the two `touch` stamp lines
(the section is offline there):

```
# Every session, offline, from what the weekly run cached: what the project is built
# on and which pins came out in the last twelve months (3.20.0).
check "session-start is quiet about pins when there is no list"  "! says 'Built on:' just session-start"
just upstream-init >/dev/null 2>&1
check "no dates yet: the session line says so, and how to fill them" "says 'not known yet' just session-start"
printf '\n[[watch]]\nname = "old"\nsource = "github:x/y"\npin = "1.0.0"\n' >> docs/upstream.toml
"$(just _py)" - <<'PY'
import json, datetime as d
t = d.date.today()
json.dump({"behind": [], "moved": [], "released": {
    "example": {"pin": "v8.30.1", "at": (t - d.timedelta(days=60)).isoformat()},
    "old":     {"pin": "1.0.0",   "at": (t - d.timedelta(days=800)).isoformat()}}},
    open(".git/upstream-cache.json", "w"))
PY
check "session-start names what the project is built on, and the pin released this year" "says 'Built on: example v8.30.1' just session-start && says 'example v8.30.1 [(]20' just session-start && ! says 'old 1.0.0 [(]' just session-start"
check "and tells the agent to read a version newer than its training" "says 'training ended' just session-start"
check "upstream <name> says when the pin came out, or that it does not know yet" "says 'released' just upstream example"
rm -f .git/upstream-cache.json docs/upstream.toml
```

Docs: `docs/01-getting-started.md` "Keeping things fresh" after "Nothing is ever
upgraded because it is newer…": "Every session it also prints, offline, what the
project is built on and which pins came out in the last twelve months, with
dates. An agent's training ends on a day, and a version released after it is one
the agent has never seen: `just upstream <name>` says where that version can be
read on this machine — the source folder, its changelog, the docs — so it is
read, not guessed." The `just upstream` comment on the same page: "…have
released, and when"; `just upstream <name>`: "that project's own release notes,
and where the pinned version's source and docs sit on this machine". "The
backbone gets stronger while you work", second bullet, and "Everyday commands"
`just session-start`: "what happened last time, what this is built on, is
anything behind".

### 10. The rule: an agent's knowledge ends on a date

Files: `.agents/skills/session/SKILL.md`, `AGENTS.md`, `.agents/skills/spec/SKILL.md`,
`.ai-backbone/templates/adr.md`, `.ai-backbone/templates/audit-lenses.md`,
`docs/01-getting-started.md`, `.ai-backbone/routine.md`, `.ai-backbone/self-test.sh`,
then `just sync-rules` (the commit carries the regenerated
`.github/copilot-instructions.md` and `.junie/guidelines.md`).

All texts are under **Rule texts**. Placement: the session skill's new
`## What you know ends on a date` goes before `## When something upstream has
moved`; its frontmatter `description` gains one clause; `AGENTS.md` §8 gains
the bullet; the spec skill's `## Rules` gains one line; `adr.md` gains
**Measured on** after **Relates to**; `audit-lenses.md` gains the paragraph after
"which is why it is first."; `routine.md` step 5 gains the clause;
`docs/01-getting-started.md` "Keeping things fresh" gains the paragraph and
"Everyday commands" `just adr` reads "write down a design decision in
docs/adr/, and what it was measured on".

Checks, after "adr gets a number and a slug":

```
check "adr asks what its claims were measured on"     "grep -q '^\*\*Measured on:\*\*' docs/adr/0001-neden-sqlite.md"
check "session skill says an agent's knowledge ends on a date" "grep -q 'What you know ends on a date' .agents/skills/session/SKILL.md"
check "AGENTS.md refuses a pinned version from memory" "grep -q 'measured on <name> <version>' AGENTS.md"
check "the spec skill points at the rule"             "grep -q 'What you know ends on a date' .agents/skills/spec/SKILL.md"
```

### 11. Release 3.20.0

Files: `.ai-backbone/core.just` line 1 (`version 3.20.0`), `CHANGELOG.md` (entry
below), `.github/workflows/checks.yml` (line 78's "Eighty checks" becomes "The
suite: …" with no number, since it was already stale), `docs/backlog.md`
(the ci-swift line's note). `just save "chore: backbone 3.20.0"`; the hook runs
the whole suite. Then, in Yerly XL: `just template-update`, `just sync-rules`,
add the §8 rule to its own `AGENTS.md` (backbone-update step 6, which
`template-update` will now say), and `just save "chore: backbone 3.20.0"`. No
`just publish` from either repo without the maintainer's word.

## Version and CHANGELOG entry

**3.20.0, minor.** New recipes (`_py`, `_ci-why`), a new fixture, a new flag and
column, a new template line, and a rule in the seed `AGENTS.md` — the precedent
for a seed rule as a minor is 3.6.0. Nothing breaks and nothing a person types
changes. The just floor moves from 1.27 to 1.29 (the 1.27 floor was never stated
either); `setup.sh` now moves an older just itself, which the routine runs first.

```
## 3.20.0 — 2026-09-19

**What you type is what runs.** `just save`, `just backbone-note`, `just spec`,
`just adr`, `just new-project` and every other recipe that takes a word from you
pasted that word into the script that runs it. A dollar sign followed by a word
stopped the save with "unbound variable"; a dollar-paren or a backtick ran as a
command and its output became the commit message; double quotes vanished on the
way. Now every recipe reads its argument the way a shell script does, as `$1`,
under `[positional-arguments]`, and the text arrives exactly as typed. Nothing
you type changes. The self-test refuses any recipe that goes back to pasting —
in `core.just`, the backbone's own `Justfile` and the stack examples. A
`stack.just` copied from the Swift example before this version keeps its old
`build-app` line, because that file is the project's own and no update touches
it. Found by Yerly XL on 2026-09-18.

**The floor, said out loud.** That attribute needs just 1.29 (June 2024); the
recipes already needed 1.27 for their groups, and nothing had ever said so.
Ubuntu 24.04's package is 1.21, and it stops at "unknown attribute" with no hint.
A check inside `just doctor` cannot help, because doctor lives in the file that
fails to parse. So `setup.sh` — the one script that runs before just reads a
recipe — compares the version, moves an older just itself (`brew upgrade just`
on a Mac, `uv tool install rust-just` elsewhere) and only then, if it is still
old, says what it found and where. `just tools-update` now also moves a just that
came through uv, which on Linux it never did. Found by reading the tools'
floors; no project paid for it. (`set minimum-version` was looked at and left
alone: on every just before 1.55 the setting is itself the first error.)

**A refusal, tried once more, and shown.** `setup.sh` asked uv once for each
tool it installs, and when a sandbox dropped that one request it ended with
"just could not be installed" and told the reader to type the command that had
just failed — the line 3.1.2 chose, back when the failure it named was real.
Now a tool uv refuses is asked for a second time, both attempts on the screen,
so uv's own words — a proxy, a directory not on the PATH — are the reason, and
the ending points at them and says to run the script again; it only adds what
is missing. The branch that said "just is installed but not on the PATH yet" is
gone: it was never true for anything this script installs. The self-test now
runs `setup.sh` with every tool faked. Seen by the backbone's own routine in a
Linux sandbox on 2026-09-18.

**A source that could not be read was reported as current.** 3.14.0 fixed the
source that answers nothing; the source that cannot be reached at all — a
proxy, a 403, a repository that is not there — was still not counted, and the
last line of `just upstream` said everything was current. Now it is counted,
its reason is printed under the UNKNOWN line, and `AI_BACKBONE_OFFLINE` makes
every source count that way, so the self-test proves it without the network.
Two more lies in the same report: a monorepo's sub-package tag
(`python/a2ui-core/v0.1.1`) read as "2 newer" because the 2 in a2ui counted as
a version, and a fresh list's own example row was MOVED on day one, pinned to a
file that never held it; the example now watches the secret scanner, at the
version the hook config really holds. And the script runs on the Python uv
already keeps for prek and graphify: a Mac's own python3 is 3.9, has no
`tomllib`, and the weekly report had been dying there in silence. Found by the
routine on 2026-09-18 and by Yerly XL's a2ui row.

**An agent's knowledge has an end date.** An agent is trained up to a day, and a
version released after it is one the agent cannot know — and it will not say
so; it remembers the version before and answers as if it were this one. Yerly
XL had made the opposite its habit: "measured, on SurrealDB 3.2.4", then a
table of what worked and what was accepted as syntax and silently did nothing.
The maintainer asked for the habit to be the rule. So the `session` skill says
it: nothing this project pins is used from memory — read what it released since
the pin, or the pinned version's own source, already on the machine, or measure
it, and write `measured on <name> <version>` into the decision. The ADR template
gains a **Measured on** line next to the **Relates to** line 3.9.0 added, the
first audit lens asks it, and `AGENTS.md` §8 gained a rule. That file is a seed,
so a project that already exists adds it by hand, as the backbone-update skill
says.

The tools follow. `just upstream` shows each pin's own release date beside it —
the day that version came out, not the newest one. `just session-start` prints,
every session and offline, what the project is built on and which pins came
out in the last twelve months, with one sentence: an agent whose training ended
before one of those dates does not know that version. And `just upstream <name>`
lists where the pinned version itself can be read on this machine: the cargo
registry folder, the `node_modules` folder next to the file that pins it, the uv
tool folder, the tool on PATH with its own `--version`, a `CHANGELOG` inside any
of those, and an optional `docs = "url"` from the watch list. Paths, not prose.
Nothing is upgraded, as before.

**A seed rule reaches nobody, and the update that would say so died on the way.**
The project that asked for the rule lacks the one rule the seed gained after it
started (3.6.0's audit rule), and nothing had told its agent. `just
template-update` now says it out loud when an entry in the span it prints names
`AGENTS.md`. And that span no longer kills the recipe: printing it through
`head` under pipefail was a SIGPIPE, certain once the jump is about ten
versions, and it died with exit 141 after copying the files — which left a
project on the daily `just projects-update` half-updated and skipped as
"unsaved work" every day after. The span is captured first and cut afterwards,
and the self-test now updates a project from 3.5.0 to prove it.

**`just ci` says why a job never started.** A failed job with no steps and no
log did not run, and GitHub writes the reason in the job's annotations and
nowhere else. `just ci` now asks for them in that one case and prints the first
sentence — "The job was not started because recent account payments have
failed…" — instead of "GitHub keeps no log for that job". Twelve of Yerly XL's
pushes were red for a day on 2026-09-18 for a billing hold found by hand.

**The Rust example, as the first project rewrote it.** `server_dir` is the root
when a `Cargo.toml` sits there and `server` otherwise, so `just check` works on
the first run in both layouts; the header names the database group as sqlx and
PostgreSQL and deletable; `fmt` applies what `lint` only complains about; and
`test-fast` is the suite without doctests, for a project that wants it before a
commit. All three were written by hand in Yerly XL.
```

## Backlog ticks

Line 19 (ci-swift) stays open. Append: ` — still open on 2026-09-19: no macOS
run has been measured yet, and 3.20.0 measured none.`

Line 22, tick:

```
- [x] 2026-09-17, Yerly XL: publish-on-save is on: a push is a public act, so save should run the project's own check before pushing and keep the commit local when it fails — today a red lint reaches GitHub and CI emails the maintainer — checked 2026-09-19, nothing to fix: the lint half closed in 3.7.0 and 3.18.0 — the hook runs `just lint` inside the commit, `save` pushes only after the commit went through, and `just doctor` warns when a project has a lint and nothing runs it. The test half is the project's: only the project knows which of its tests are cheap enough for every save, and Yerly XL answered it the same day with a `just test-fast` hook before the commit (9 s of a 37 s suite, commit 6755d91), while spec 009 keeps a commit cheap for everyone else; 3.20.0 ships `test-fast` in the Rust example. A gate before the push would not keep a red commit local anyway: the next green save pushes HEAD and every commit under it. The e-mails a day later were GitHub's spending limit, a separate matter.
```

Line 23, tick:

```
- [x] 2026-09-18, ai-backbone: just upstream says 'Everything watched is current.' when it could not read a single source. […unchanged…] Test it with a watch list whose source cannot be reached. — done in 3.20.0: the row now puts `unreachable` where the blind list looks, prints the reason under the UNKNOWN line, and AI_BACKBONE_OFFLINE makes every source count that way, so the self-test proves it with no network at all. On the way: a monorepo's sub-package tag no longer reads as newer, the template's example row is true on day one, and the script runs on the Python uv keeps.
```

Line 24, tick:

```
- [x] 2026-09-18, ai-backbone: sh .ai-backbone/setup.sh -y ended with 'just could not be installed' on a fresh Linux sandbox […unchanged…] Consider one retry, and printing what uv actually said. — done in 3.20.0: each uv install is asked twice, both attempts on the screen, so uv's own words are the reason; the ending says just is not on the PATH and points at them instead of a command to retype; the unreachable "not on the PATH yet" branch is gone. The self-test runs setup.sh with every tool faked. The run's own output was never recorded, so which of the two suspects it was stays unknown; next time the screen will say.
```

Line 25, tick:

```
- [x] 2026-09-18, Yerly XL: just save and just backbone-note splice their text argument into the recipe's bash script unquoted […unchanged…] never as a just interpolation inside the script body. — done in 3.20.0: every recipe that takes a parameter — twenty-one in core.just, the backbone's own Justfile, the Swift example's build-app — carries `[positional-arguments]` and reads `$1`; a self-test guard lists any recipe that goes back to `{{param}}`. A global `set positional-arguments` was rejected: it reaches the project's own recipes and is a hard error when the project sets it too. Needs just 1.29, which setup.sh now checks.
```

## Rule texts, ready to paste

**`.agents/skills/session/SKILL.md`, frontmatter `description`, appended clause:**

```
…and just session-end, and what to do when something the project is built on has moved, or is newer than what you know.
```

**Session skill, Start step 1:**

```
1. Run `just session-start`. It prints the last two journal entries, recent
   commits, the working tree, what the project is built on, and whether the
   backbone has updates.
```

**Session skill, new section before `## When something upstream has moved`:**

```
## What you know ends on a date

An agent is trained up to a day. A version released after it is one the agent
cannot know, and it will not say so: it remembers the version before and
answers as if it were this one. So nothing this project pins — the watch list
in `docs/upstream.toml` first, but a lockfile pin too — is used from memory.

Every `just session-start` prints what the project is built on and which of
those pins came out in the last twelve months, with dates, from the weekly
check's cache. A version released after your training ended is one you do not
know. Three ways to know, cheapest first:

1. `just upstream <name>`: what it released between the pin and today, and
   where the pinned version itself can be read on this machine — the source
   folder, its changelog, the docs (a watch may carry `docs = "url"`).
2. That source. A signature, a default, a behaviour you are about to rely on:
   find it there first. When it is not there, the memory was of another version.
3. A test, run against the pinned version and kept.

The decision that rests on it says so in the ADR — `measured on <name>
<version>`, with the date; the template has the line. A claim without it is a
memory, and a memory is older than the pin.
```

**Session skill, "When something upstream has moved", point 1:**

```
1. `just upstream <name>` prints that project's own release notes. Read them.
   It also lists where the pinned version itself lives on this machine: the
   source folder, its changelog, the docs.
```

**`AGENTS.md` §8, appended bullet (seed; existing projects add it by hand):**

```
- Do not use a feature of a pinned version from memory. Your training ended on
  a day and the pin may be past it: read its notes (`just upstream <name>`) or
  its source on this machine, or measure it, and write `measured on <name>
  <version>` in the ADR.
```

**`.agents/skills/spec/SKILL.md`, `## Rules`, appended:**

```
- A claim about what a pinned thing does names the version it was measured on
  (session skill, "What you know ends on a date"). Never from memory.
```

**`.ai-backbone/templates/adr.md`, after the Relates-to paragraph:**

```
**Measured on:** what the claims below were checked against — the thing, its version
and the date: "<thing> <version>, YYYY-MM-DD". "Nothing" when no claim here was
measured, and then say why not. A version an agent remembers is a version that has
moved on.
```

**`.ai-backbone/templates/audit-lenses.md`, Documents against code, after "which is why it is first.":**

```
For every claim about what a library, a database or a tool does, ask which
version it was measured on. A claim with no version was written from memory,
and memory is of an older version than the one this project pins.
```

**`.ai-backbone/core.just` header, after line 4:**

```
#
# A recipe that takes an argument reads it as `$1` under `[positional-arguments]`,
# the attribute on the line directly above its header. Never write `{{arg}}`
# inside a script: whatever the person typed would run as a command.
#
# Needs just 1.29.0 or newer (the [positional-arguments] attribute). setup.sh
# says so before an older just stops at "unknown attribute".
```

**`.agents/skills/backbone-dev/SKILL.md`, after "Never patch `.ai-backbone/core.just` in the project…":**

```
A recipe that takes an argument reads it as `$1` under `[positional-arguments]`
(the line directly above its header) and never writes `{{arg}}` inside its
script: whatever the person typed would run as a command. The backbone's
self-test refuses a recipe that does. The same holds for a recipe you add to a
project's `Justfile` or `stack.just`, where no test looks.
```

**`.ai-backbone/examples/README.md`, one line:** "A recipe that takes an
argument carries `[positional-arguments]` and reads `$1`, never `{{arg}}` in
its script — `build-app` in `stack-swift.just` is the example."

**`.ai-backbone/routine.md` step 1 and `templates/routine-project.md` step 1:**

```
If `just` or `prek` cannot be installed, or `just` is too old, stop and say so,
quoting what the script printed under the tool's name (`-> just`, `-> prek`).
```

**`.ai-backbone/routine.md` step 5, appended clause:** "…and what the new
version does is read or measured, never remembered (same skill)."

**`.ai-backbone/templates/upstream.toml`, legend additions:**

```
#   docs        optional: where that version's own documentation lives, a URL
#   A tool that lives as a binary and in no file has no pinned_in; MOVED cannot
#   be said for it. `check` may be a multi-line string: check = """…"""
```

**`setup.sh` ending (else branch):**

```
just is not on the PATH. What the installer said above, under '-> just', says why.
Fix that and run this script again; it only adds what is missing.
```

**`setup.sh` floor lines:** `-> just 1.21.0 at /usr/bin/just is older than
1.29.0, which the recipes need` and, if still old after the move, `just is still
1.21.0 at /usr/bin/just; the recipes need 1.29.0 or newer.` / `  Mac:   brew
upgrade just        Linux:  uv tool install rust-just`.

**`template-update` reminder:**

```
An entry in this span names AGENTS.md. That file is this project's own and is
never updated: read the entry and add the rule by hand (backbone-update skill, step 6).
```

**`session-start` every-session lines (`upstream.py --recent`):**

```
Built on: rust 1.98.1 · surrealdb 3.2.4 · … · typescript 7.0.2 (docs/upstream.toml)
Released in the last 12 months: solid-js 2.0.0-rc.8 (2026-09-11), vite 8.3.0 (2026-09-10), …
An agent whose training ended before one of those dates does not know that version. Read it first: just upstream <name>
```

or `Released in the last 12 months: not known yet. The weekly check fills it in
when the sources can be reached: just upstream`, or `Released in the last 12
months: none.`

**`upstream.py` messages:** `UNKNOWN: <names> — nothing came back from the
source. A watch that cannot read its source is not a watch; fix the source or
stop watching it.` then `   <name>: <reason>` per name; last line `Everything
readable is current. Could not read: <names>.`; `just upstream <name>` on a
silent source: `   the source could not be read: <reason>`; the Python guard:
`Needs Python 3.11 or newer for tomllib; this is 3.9.6. uv can put one on this
machine: uv python install 3.13`.

**`just ci`:** `    The job never started. GitHub's reason: <first sentence of the annotation>`.

**`tools-update` recipe comment:** `# Update the tools this repo relies on: prek, graphify, the hook versions, and a just that uv installed`.

## Addenda — 2026-09-19, after approval

What changed while this was being built. Each line is part of the plan.

- **A1. 3.19.1 arrived from the scheduled routine, mid-build.** It counts a
  source that could not be reached and prints the reason (the first bullet of
  task 8). It is merged into `main`. Task 8 builds on it, keeps its check, and
  does what is left: `AI_BACKBONE_OFFLINE`, the monorepo tag, the example row,
  `_py`, the lazy `tomllib` guard, `upstream <name>` on a silent source. The
  backlog line of 2026-09-18 is already ticked there; the release rewrites the
  CHANGELOG paragraph to say what 3.19.1 did and what 3.20.0 adds.
- **A2. The suite drops the git variables a hook hands it.** Done (e47bd6f). A
  commit from a linked worktree ran the suite with git's own `GIT_DIR`, and its
  throwaway projects' `git init` and `git remote` landed in the real
  repository: it went bare and lost its GitHub address. Repaired by hand;
  re-enacted on a throwaway repository, where the old suite does the same
  damage and the fixed one does none. Tracks therefore build in plain clones,
  never in linked worktrees.
- **A3. `pub:name`** is a fourth source kind for `just upstream` (pub.dev), with
  the package's folder in the pub cache and its documentation in the
  where-list. The maintainer will build Flutter games on this backbone.
- **A4. One way to update a project, not two.** `just projects-update`,
  `just projects-update-schedule` and the `update` mode of
  `.ai-backbone/projects.sh` go; `just projects` (the table) stays. Every
  `just session-start` in a project already refreshes the backbone from GitHub
  and says when the project is behind, and the agent working there updates it
  at a moment it knows is safe. The scheduled job was the only thing that wrote
  into a project from outside while somebody might be working in it, and on
  2026-09-18 it left Yerly XL at "update FAILED". The maintainer approved the
  removal; the two launchd jobs on his Mac are already gone. The backbone's own
  weekly local routine is gone too — the cloud routine does that work daily —
  while `just routine-install` stays, for projects.
- **A5. `just routine-remove` ends with three unbound variables** and a garbled
  hint (`just routine-install " "`): its last line uses `$names`, `$day`, `$hour`
  and `$minute`, which that recipe never sets. Read the schedule from the plist
  before deleting it, or drop the hint. Seen while removing the local routine.
- **A6. The plan goes to GitHub first, and the routine skips what it claims.**
  3.19.1 and this spec fixed the same backlog line on the same night because
  the spec sat on one machine for hours. `routine.md` step 6: a backlog line
  that an approved, unfinished spec in `docs/specs/` says it closes is
  somebody's already — skip it. backbone-dev skill: work that gets a spec publishes
  it before it builds, whatever its size, and the spec names the backlog lines
  it closes.

## Addenda — 2026-09-19, after the review

Six lenses read the build, two skeptics tried every finding; twenty-nine
findings, two refused. What changed the plan is here, so the plan and the code
agree. Where a line below differs from the body or from "Rule texts", this wins.

- **A7. The entry opens with what is added by hand.** The update that brings
  3.20.0 into a project is run by the project's OLD recipe: it prints the first
  sixty lines of the span, has no `AGENTS.md` reminder, and a second run only
  says "Already up to date". So the 3.20.0 CHANGELOG entry opens, directly under
  its heading, with the `AGENTS.md` §8 bullet quoted as shipped (A10) and the
  audit-lens paragraph a project with its own `docs/audit-lenses.md` adds by
  hand. Re-enacted from 3.19.0 (fifteen of fifteen runs exit 0) and from 3.17.1
  (eight of eight): the jump Yerly XL makes does not die with 141; only a span
  of about ten versions does. For Yerly XL: `just template-update` once; read
  `.ai-backbone/CHANGELOG.md` from the top down to 3.19.0; add the §8 bullet and
  the lens paragraph by hand; `just sync-rules`; `just save`.
- **A8. No zip copy.** README "Staying current" and the getting-started line for
  `just template-update` drop "a zip copy first": no zip has been made since
  3.0.0, and git is the way back. Task 4's Docs bullet reads without those words.
- **A9. Two endings, not one.** 3.19.1's endings are kept, so where the body
  gives one last line (acceptance line 4, task 8, the rule texts) read two: a
  fresh project after `just upstream-init`, offline, ends "Nothing could be
  read: example. This report says nothing about what is current; it says the
  sources could not be reached." and no line starts with "Everything";
  "Everything readable is current. Could not read: <names>." is the ending when
  some sources answered and none of them is newer.
- **A10. The §8 bullet as shipped:** "…or its source on this machine, or measure
  it. In an ADR that rests on it, write `measured on <name> <version>`." Not
  every use of a pinned feature has an ADR, and the phrase stays on one line,
  which the suite's grep needs. The session skill also says what to do without
  a training date of your own (treat every pin as newer), that the list stops
  at twelve months, and that a project with no watch list is told nothing —
  which means nobody is watching, not that nothing is new.
- **A11. Versions as they are really written** (`upstream.py`): a number inside
  a suffix is a number (rc.10 sorted before rc.9, and Yerly XL pins a release
  candidate); `+build` is a build, not a prerelease; a GitHub release is dated
  by the earlier of its two days (SurrealDB writes its release pages in
  batches: 3.2.4 existed on 2026-08-03 and its page is dated 2026-08-17); a pin
  without quotes and a list with one bracket are said in words; columns are as
  wide as what is in them; a tags-only project is read without gh; three
  sources in a row that do not answer end the asking (five minutes of silence
  at session start, measured on a list of thirteen); `just upstream <name>` on
  a silent source exits 0, because what is on this machine was the answer.
- **A12. Checks that could not fail, and a harness that could not see.** The
  tomllib check runs once there is a list (without one the script answers
  before it needs tomllib); the unquoted-pin check carries `pinned_in`; the
  setup.sh checks run under dash where there is one, with a system folder of
  their own (a bash-only line was green on a Mac; a packaged just in /usr/bin
  shadowed "no just"); the floor asks uv twice like every other install and
  ends "What the installer said above says why…" instead of a command to
  retype; `_ci-why` is held to its first sentence; the splice guard's header
  pattern is `/^@?[A-Za-z_][A-Za-z0-9_-]* +[+*$]?[A-Za-z_].*:/ && !/:=/`, which
  sees a quiet `@name arg:` and a single-quoted default. routine.md's step
  references moved by one and its report is no longer called weekly;
  getting-started says which installs are asked for twice and no longer lists
  git among the tools checked weekly.
- **Left for the backlog, on purpose:** setup.sh's exit code is 0 when just
  could not be installed at all and 1 when it is merely too old; `just ci`'s
  "never started" line would also be printed for a job that lost its runner;
  `just save` refuses a linked worktree with "No git repo yet"; what makes a
  spec's claim on a backlog line lapse; the ADR template's "Nothing" takes any
  reason.
