# Documentation

Public, English, safe to publish. This is the backbone's own documentation;
a project built on it starts with a two-line `docs/README.md` of its own.

| Page | Content |
|---|---|
| `01-getting-started.md` | install, set up, first commands, what goes where, what the hidden folders are |
| [`how-it-works.md`](how-it-works.md) | two pictures GitHub draws by itself, for a person who does not read code: how a note from a project becomes a new version in every project, and the life of one idea |
| `specs/` | one page per idea, written before the code, `just spec <name>` |
| `adr/` | architecture decisions, one file each, numbered, newest last, `just adr <name>`; one that changes an earlier one: `just adr <name> --amends NNNN` |
| `backlog.md` | notes from the projects for the backbone, `just backbone-note "..."`; agents work through the open lines, `- [?]` lines wait for the maintainer |
| `routine-log.md` | one line per run of the scheduled agent: its only memory, since its sandbox keeps nothing |
| `radar.toml` | what the scheduled agent reads on a Sunday, and how far it has read: `just radar` |

`.ai-backbone/routine.md` is the brief for a scheduled agent that works the
backlog on its own (Claude routine, Cursor cloud agent or a GitHub Action).
`.ai-backbone/templates/routine-project.md` is the same for a project: one task
of the oldest approved spec per run. A project is updated from the inside: its
own `just session-start` brings the backbone next to it level with GitHub
(and says why when it cannot), says when the project is behind, and the agent
working there updates it.

Ready language layers live in `.ai-backbone/examples/` and arrive in a project
with `just stack rust`, `just stack swift` or `just stack flutter`; `just stack`
alone lists them.

`just self-test` builds throwaway projects and adopts an existing repo, all in
a temp folder, and checks what a person would see. A git hook runs it whenever
a commit touches the core.

`just projects` lists every project built on this backbone that sits next to it:
backbone version, unsaved work, GitHub address, last save.

Agents keep this folder current: when code changes something described here,
the page changes in the same session.

Anything private, half-formed, or in your own language belongs in `brain/`.
