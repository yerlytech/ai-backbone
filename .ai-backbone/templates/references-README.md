# References — READ ONLY

Other people's repos, and older versions of your own, kept for reference.

## Rules

1. **Never write here.** No edits, no moves, no deletes.
2. Read them. Copy the idea out. Do not copy the folder in.
3. Nothing here is committed. `references.toml` records where each one lives.

## A folder with no address

A reference may be a folder on this machine that lives nowhere else: an old repo
of yours with no remote. `just ref-add <folder> "why"` lists it with `url = ""`.
A git repository is cloned in (one that has an address elsewhere is listed with
that address); a folder already in `.references/` is listed where it stands.
A folder can also be listed by hand with `path` in place of `url`: it is read
where it stands. `just ref-fetch` cannot bring a local-only one back on another
machine; it says which are there and which are not. Keep a second copy of it
yourself if it matters.

## Why

Old code is worth reading and dangerous to depend on. Keeping it read-only
means an agent can learn from it without quietly reviving it.
