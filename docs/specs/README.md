# Specs

One page per idea, written before the code. English, public.

```bash
just spec my-idea      # creates NNN-my-idea.md from _template.md
```

Every spec carries a `status:` line: `draft` → `approved` → `done`, or
`abandoned`. Nothing is written until the maintainer says `approved`.
Nothing is ever deleted; an abandoned spec is a record of a decision.

The spec says what and why. How it was built belongs in `adr/` if it was a
decision worth remembering, and in the code otherwise.
