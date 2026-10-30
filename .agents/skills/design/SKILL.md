---
name: design
description: The design principles every project built on ai-backbone follows - boundaries, a pure core, types that refuse bad states, money and numbers, invariants, errors, retries and idempotency, concurrency, limits and their override, secrets, dependencies, data, doors, interfaces and tests - and the Rust review checklist. Use when writing a spec's design, building a module, changing how two parts talk, reviewing a diff, or running the audit's design lens.
---

# Design

These are the rules the code is held to. They are not a style guide: each one
exists because breaking it costs money, data or a weekend. Every rule says why,
what it looks like, and how a reviewer checks it. When two rules pull apart, the
order is: **people's money and data, then security, then correctness, then
simplicity, then speed.**

Simple and sound are not opposites. Simple means few parts and no speculation.
Sound means the parts that exist cannot be misused. Build the smallest thing
that works, and make that thing impossible to break quietly.

## 1. Build only what is asked, but leave the seams

- Ship the simplest design that meets the spec's acceptance list. No option,
  layer, trait or setting for a case nobody has asked for (YAGNI).
- A seam is different from a feature: where something talks to the outside
  (a database, a network service, a clock, a random source, a file system, a
  payment or signing service), put it behind one narrow interface, so a test
  can stand in for it and a second provider can be added without touching the
  callers.
- Three copies of the same logic is the moment to share it, not two. Shared
  code that serves two masters with flags is worse than two copies.

*Check:* every public function, type and setting has a caller and a test today.
Every outside call goes through one place.

## 2. Boundaries: one owner for each thing

- Each piece of state has exactly one owner (a module, a service, a product).
  Others ask the owner through its contract: a function, an event, a door. They
  never read or write its tables, files or memory directly.
- A product never connects to another product's database; it calls that
  product's door. A module never names another module's internals; the platform
  carries what passes between them.
- Dependencies point inward: the domain (rules, calculations, decisions) does
  not import the web framework, the database driver or the HTTP client. Those
  import the domain.

*Check:* grep the diff for another module's table names, another crate's private
paths, or a domain file importing I/O crates.

## 3. A pure core, a thin shell

- Decisions are pure functions over values: given the inputs, the same answer,
  no I/O, no clock, no randomness inside. The clock and the random source are
  passed in.
- The shell does the I/O: reads, calls, writes, sends. It holds as little logic
  as possible, so most of the behaviour is testable in milliseconds without a
  network or a database.
- Example to copy: a trading desk's limits are one function from (book, trade,
  prices, now) to "allowed" or a named refusal; the code that talks to the chain
  only executes what that function allowed.

*Check:* the interesting branches of a change are covered by unit tests that
need no container, socket or sleep.

## 4. Types that refuse bad states

- Parse at the edge, then trust the type: input from a person, a file or a
  network becomes a checked type once (an email, an IBAN, a tax number, an
  amount, an id). Inner code takes the type, never the raw string.
- Prefer an enum to a boolean or a string for anything with states. A record
  that can be `draft`, `issued` or `void` is an enum, and code that matches it
  must handle every arm.
- Newtypes for ids so one kind of id cannot be passed where another belongs.
- Make the invalid combination unrepresentable rather than checked: a type that
  holds either a sent invoice with its number or a draft without one, not one
  struct with an optional number and a comment.

*Check:* no `String`, `bool` or `u64` parameter whose meaning lives only in its
name; no `Option` that is "always set after step 2".

## 5. Money, quantities and numbers

- Money is a decimal with its currency, never a float. A quantity carries its
  unit. Adding two currencies or two incompatible units is an error the type
  returns, not a bug a test may catch.
- Arithmetic that can fail (overflow, division by zero, a mixed currency)
  returns a `Result`; it never panics and never wraps silently.
- Every rounding names its rule and its place (half up at the currency's
  places, banker's rounding, truncation toward zero for a minimum) in one
  shared function. The database and the screen use the same rule, and a test
  holds them equal.
- Totals are computed where the data lives (the database's sum), once, and
  shown; they are not recomputed differently in three layers.
- External amounts arrive in base units (lamports, cents, satoshis) and are
  converted at the edge with the asset's own decimals.

*Check:* no `f32`/`f64` near money or quantities; no `as` cast on an amount;
every rounding call names its rule.

## 6. Invariants are written, enforced and tested

- Each product keeps `docs/invariants.md`: the statements that must always be
  true (a journal entry balances; a posted entry never changes, only reverses;
  a wallet's book equals the chain; a claim is approved once).
- Each invariant names who enforces it, in this order of preference: the
  database (a unique index, an assertion, a transaction, a computed field),
  the type system, the code path, and only last a periodic check that reports.
- Each invariant names its test. An invariant without a test is a wish.
- A periodic consistency check runs in production for the invariants that
  cannot be enforced at write time, and it alarms rather than repairs.

*Check:* a change that touches stored state names the invariants it touches,
and their tests still pass.

## 7. Errors

- Errors are typed and carry context: what was being done, with which
  identifiers, and the cause. "error sending request" alone is not an error
  message; "the Solana node closed the connection while reading holders of
  <mint>" is.
- No `unwrap`, `expect` or `panic!` on a production path. They are allowed in
  tests, in `main` before the service starts (a bad configuration), and where a
  comment proves the case impossible.
- Fail closed where money, security or people's data are involved: when in
  doubt, refuse and say why. Fail open only for conveniences (a missing
  thumbnail).
- A person sees a plain sentence in their language and a reference; the log
  holds the detail. Neither ever holds a secret, a key, a token or a URL that
  carries one.
- An error that is retried is logged once with its count, not on every try.

*Check:* grep the diff for `unwrap()`, `expect(`, `panic!`, `todo!`,
`unimplemented!`, and for `{:?}` of a request, a URL or a config in a log line.

## 8. Calls to the outside: timeouts, retries, idempotency

- Every outside call has a timeout. There is no call that can wait forever.
- Retry only what is safe to repeat: reads, and writes that carry an
  idempotency key the other side honours. Retry with backoff and jitter, a small
  fixed number of times, and name the error kinds that are retried (a closed
  connection, a 429, a 503 with Retry-After). Never retry a 4xx that means "you
  are wrong".
- A write that may be sent twice (a click, a retry, a restart mid-flight)
  carries an idempotency key derived from who, what and which version, so the
  second arrival does nothing.
- A transaction that moves value records its intent before it is sent and its
  outcome after, so a crash in between is resolved by reading the other side,
  never by guessing.

*Check:* each new outside call shows its timeout, its retry rule and its
idempotency key, or says in a comment why it needs none.

## 9. Concurrency

- One writer per piece of state, or a transaction or lock that makes the
  writers take turns; say which in a comment.
- Do not hold a lock across an `.await` that does I/O unless that is the point,
  and then say so.
- Queues and channels are bounded. An unbounded queue is a memory leak waiting
  for a busy day.
- Shared state is the exception; pass messages or values where you can.
- Test the writers together: two requests at once, a restart in the middle, a
  kill during a write.

*Check:* every `Mutex`/`RwLock`/lock has a comment on what it protects; no
`unbounded_channel` without a reason.

## 10. Limits, guards and their override

- A safety limit (a maximum trade, a daily cap, a rate, a price impact, a
  payout ceiling) is data with a name, a value and a reason, in one place, and a
  refusal names the limit it hit.
- Limits are layered on purpose: the program checks its own, and a separate
  guard that the program cannot change (a signer, a gateway, a database rule)
  checks again.
- Every limit that the owner may one day need to lift has a designed override:
  a named command or act, used only by the owner's word, logged with who, when
  and why, as narrow as the case (an exit-only order may skip the floor; it may
  not buy). Discovering on the day that the only way out is a code change is a
  design failure.
- Lowering a limit is easy; raising one is a decision written in the code's
  comment or an ADR with the date and who decided.

*Check:* a new limit names its override, or says why it has none.

## 11. Secrets and privilege

- Secrets live in files or a key service, are read at the moment of use, and
  never appear in a log, a page, an error, a chain, a commit or a chat.
- A key is sent only where it belongs (`Authorization: Bearer`), never in a
  URL or a query string.
- Each process gets the least it needs: a read-only database user for readers,
  a signer that only signs what its rules allow, a token scoped to one action.
- Personal data is shown at the moment of reading and kept nowhere it is not
  needed; an identifier that is not an e-mail or a name is used in logs.

*Check:* grep the diff for key names, `password`, `token`, `secret` in log and
format strings; every new credential names its file and its scope.

## 12. Dependencies

- Few, pinned, and each with a reason in a comment where it is declared.
- A new dependency starts at its current release, read from its changelog, not
  from memory. A move reads the changelog first and names what touches us.
- Prefer the platform's or the standard library's tool to a new crate; prefer a
  crate the workspace already builds to a second one doing the same job.
- One version of a library across the lock where the ecosystem allows it.

*Check:* every new line in `Cargo.toml`/`package.json`/`pubspec.yaml` has its
reason; `docs/upstream.toml` watches it.

## 13. Data and its changes

- The schema lives in code and in version control; a change to it is a
  migration that runs forward, is tested on a copy of real-shaped data, and is
  undone by the backup, not by a down-migration nobody ran.
- Data belongs to one module (rule 2). A field another module needs is read
  through the owner or published as an event.
- Nothing destructive happens without a backup taken first and a restore that
  has been rehearsed.
- Times are stored in UTC with their zone named; days that matter to people
  (a VAT period, a closing day) are stored as dates in the zone that defines
  them.

## 14. Doors and APIs

- Versioned paths (`/door/v1/…`), one meaning per path, documented beside the
  code.
- Every write takes an idempotency key; every read pages by cursor.
- Answers never leak internal ids, e-mail addresses or stack traces; refusals
  are named codes with a plain sentence.
- A door answers within its time budget or says it cannot; a caller treats
  silence as "unavailable", not as "no".

## 15. Interfaces for people

- Designed at phone width first, then desktop; walked at 390 and 1280 px.
- Every screen has its loading, empty, error and success states designed, not
  left to chance.
- One primary action per screen. A destructive or money-moving action asks for
  confirmation that names what will happen.
- Accessible by default: labels, contrast, focus order, targets of 44 px.
- Words are the product's language, plain, and the same thing has the same
  name everywhere.

## 16. Tests

- Test behaviour, not implementation: a test names what a person or a caller
  can rely on, and survives a refactor.
- One test per acceptance line and per invariant, named so the spec can cite
  it.
- Fakes stand in at the seams (rule 1); the real thing is exercised in an
  integration test and in a walk on the real stack before a release.
- Where the input space is large (parsers, money arithmetic, limits), add a
  property or differential test.
- A bug fix starts with the test that fails without it.

## 17. Change discipline

- Spec first for anything larger than a small fix; an ADR for a decision that is
  hard to reverse (a database, a protocol, a key's custody, a limit's raise).
- Small commits, each with its tests and its docs; documentation follows code
  in the same change.
- Do not refactor working code while adding a feature; do it as its own change
  with its own tests.
- Names say what a thing is; comments say why, and what was measured.

## Rust review checklist

The audit's design lens and every review of Rust code go through this list.
Each item is a question with a yes that must be justified in the code.

1. `unwrap()`, `expect()`, `panic!`, `todo!`, `unimplemented!` on a production
   path?
2. `unsafe` without a `// SAFETY:` comment that proves the conditions?
3. A `#[must_use]` value (a `Result`, a future, a guard) dropped or bound to
   `_`?
4. An error returned without context (`?` straight through where the caller
   cannot tell what was being done)? Use `.context(...)` or a typed error with
   fields.
5. `String` or `Box<dyn Error>` as a library's error type where callers need to
   branch on the kind?
6. An `as` cast on an amount, a length or an index that can truncate or change
   sign? Use `try_from`.
7. Blocking work (file I/O, a CPU-heavy loop, `std::thread::sleep`) inside
   `async` without `spawn_blocking`?
8. A lock guard held across an `.await`?
9. An unbounded channel, queue or `Vec` fed from the outside?
10. An outside call with no timeout?
11. `clone()` of a large value inside a loop, or a collection rebuilt per item?
12. A float near money or a quantity?
13. A secret, token or keyed URL in a `Debug` derive, a log or an error?
14. A public item with no caller and no test?
15. `cargo clippy --all-targets -- -D warnings` clean, with any `allow` carrying
    its reason?

## Using this skill

- **In a spec:** the design paragraph says which of these rules the change
  touches and how it keeps them (the owner, the seam, the invariants, the
  limits, the retries).
- **In review:** read the diff against the "Check" lines of the rules it
  touches and the Rust checklist; a finding cites the rule's number.
- **In an audit:** "design" is one lens; its agent reads the code against this
  file and verifies each finding before it is reported (the audit skill).
- **When a rule is wrong for a case:** say so in the code's comment with the
  reason, and propose the change to this file through the backbone, not by
  ignoring it quietly.
