# Archive

Retired but worth keeping. Committed, so it survives.

Agents do not read this folder unless asked. Every file starts with a line
saying when it was archived and why.

## legacy/

When a project is rebuilt rather than migrated, the repository it replaces is kept
here as a **git bundle**: one file holding the entire history.

```bash
# read it without unpacking
git clone .archive/legacy/<name>.bundle /tmp/old
```

A bundle is exempt from the large-file hook. It is written once and never edited.
Alongside it, a short note says what the project was, why it was replaced, and
anything the bundle does **not** contain, because a bundle only holds what git
tracked. Files that lived only on a server or only on a disk are not in it.
