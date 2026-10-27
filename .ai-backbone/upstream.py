#!/usr/bin/env python3
"""What the things this project is built on have released since we pinned them.

Reads `docs/upstream.toml`, asks each source what it has published, and prints
what is newer than the pin. With a name, prints the release notes themselves,
because the version number is the least useful half of the answer: what matters
is what changed and what it costs to follow.

It also says when each pinned version came out and where that version can be
read on this machine, because an agent's training ends on a day and a version
released after it is one the agent has never seen. `--recent` prints that from
the cache alone, without the network, for every session. A source is asked at
most once a day per machine: the answer is kept under
`~/.cache/ai-backbone/upstream/`, keyed by source, and every project that
watches that source reads the same file. `--refresh` asks again.
`--freshness` is the short block session start shows: what is behind, what
moved, and one first job. It stops at ten seconds and still exits 0.
`--advisories` reads
a Cargo.lock against the RustSec advisories, and `--crate-sources` says when
a row reads from GitHub what Cargo.lock locks as a crate (spec 029); what a
project has looked at and ships anyway is in docs/advisories.toml, and
`--advisories gate` is a ship's yes or no (spec 030).

Nothing here upgrades anything. It reports.
"""

import collections
import datetime
import glob
import hashlib
import http.client
import io
import json
import os
import re
import shutil
import socket
import subprocess
import sys
import tarfile
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

# Python on Windows writes "\r\n" for every "\n", and the recipes compare what
# it says as text: "removed\r" is not "removed" (spec 020). LF on every machine;
# the encoding is PYTHONUTF8's, which core.just sets.
for _stream in (sys.stdout, sys.stderr):
    # TextIO has no reconfigure in the type stubs; the real streams are wrappers.
    if isinstance(_stream, io.TextIOWrapper):
        _stream.reconfigure(newline="\n")

LIST = Path("docs/upstream.toml")
CACHE = Path(".git/upstream-cache.json")
# The self-test sets this, and so does anybody who must not reach the network.
# Every source then counts as unreachable, which is also the one case the report
# must never dress up as good news (3.20.0).
OFFLINE = bool(os.environ.get("AI_BACKBONE_OFFLINE"))
# How long a shared answer is the answer (spec 035). A rate limit and a check
# that ran out of time count from the try, so the next session does not spend
# them again. Offline does not: a morning with no network must not use up the day.
SHARE_DAY = 86400
# Session start stops starting new lookups once the whole check has taken this
# long, and shows the last result (spec 035). `just upstream` itself waits: a
# person who typed it is waiting for the answer. The suite sets the budget to
# zero to exercise the stop without sleeping.
FRESH_BUDGET = float(os.environ.get("AI_BACKBONE_UPSTREAM_BUDGET", "10") or "10")
# npm outdated and npm audit run beside the RustSec check at session start
# (spec 035's block). One call may spend this long, and the whole check this
# long: a slow registry is a line saying so, never a session waiting on it.
NPM_TIMEOUT = float(os.environ.get("AI_BACKBONE_NPM_TIMEOUT", "6") or "6")
NPM_BUDGET = float(os.environ.get("AI_BACKBONE_NPM_BUDGET", "8") or "8")
# Folders that are not the project's own packages: a dependency tree, another
# repository, a retired copy, the code map's output.
NPM_SKIP = {"node_modules", ".git", ".references", ".archive", "graphify-out"}
# The deadline of the check that is running, or None when a person typed
# `just upstream` and is waiting. A lookup uses the shorter of its own limit
# and what is left, so one source's thirty seconds cannot spend the ten.
CALL_DEADLINE = None


def call_timeout(default):
    """How long this one call may take. Past the session's deadline, a fraction
    of a second: long enough to fail, not long enough to hold the session."""
    if CALL_DEADLINE is None:
        return default
    left = CALL_DEADLINE - time.monotonic()
    if left <= 0.05:
        return 0.05
    return min(default, left)


def say(line=""):
    print(line, flush=True)


def fetch_json(url, headers=None):
    request = urllib.request.Request(url, headers=headers or {"User-Agent": "ai-backbone"})
    with urllib.request.urlopen(request, timeout=call_timeout(10)) as response:
        return json.load(response)


def fetch_text(url):
    """A channel pointer is plain text more often than not: the tool's own
    updater reads one version from the address and nothing else."""
    request = urllib.request.Request(url, headers={"User-Agent": "ai-backbone"})
    with urllib.request.urlopen(request, timeout=call_timeout(10)) as response:
        return response.read().decode("utf-8", "replace")


class Unreachable(Exception):
    """The source could not be read. Not the same as "nothing newer", and the
    difference matters: one is an answer and the other is silence wearing one."""


def release_day(r):
    """GitHub gives a release two days: when its page was published and when the
    commit it tags was made. A project that writes its pages in batches would
    date a version by its paperwork — one tool's last four patch releases share
    one afternoon, two weeks after the last of them was published — so the
    earlier day is the one the version existed on."""
    days = [d[:10] for d in (r.get("published_at"), r.get("created_at")) if d]
    return min(days) if days else ""


def tag_rows(repo, tags):
    return [
        {"version": t.get("name", ""), "at": "", "title": t.get("name", ""),
         "notes": "", "url": f"https://github.com/{repo}/releases/tag/{t.get('name','')}",
         "prerelease": False}
        for t in tags
    ]


def tags_with_git(repo, why):
    """The tags of a public repository, asked of git itself, newest first. A cloud
    sandbox's GitHub proxy answers the API only for the repository attached to
    the session and gives every other one a 403, by design, so a scheduled run
    read none of the four tools this backbone stands on. `git ls-remote` of a
    public repository still works there (measured 2026-09-19, spec 012). Names
    only, no days and no notes: enough to say "newer", which is the question.
    Every tag, not the fifty highest: a repository tags more than one thing, and
    sorted together openai/codex's newest `rust-v` release stood at place 49,
    behind build tags and another package's (measured 2026-09-19), so the pin
    itself fell off the end. newer_than() keeps to the pin's own label."""
    try:
        done = subprocess.run(
            ["git", "ls-remote", "--tags", "--refs", f"https://github.com/{repo}"],
            check=False, capture_output=True, text=True, timeout=call_timeout(30),
            env={**os.environ, "GIT_TERMINAL_PROMPT": "0"},
        )
    except (OSError, subprocess.TimeoutExpired):
        raise Unreachable(f"{repo}: git could not list the tags either, after {why}")
    # The phrase that matters comes first: a reason is cut at 120 characters,
    # and on a Linux runner gh sits in /usr/bin and fails with a long sentence
    # that pushed "git could not list" past the cut (measured 2026-09-24).
    names = [line.split("refs/tags/", 1)[1] for line in done.stdout.splitlines() if "refs/tags/" in line]
    if done.returncode != 0 or not names:
        raise Unreachable(f"{repo}: git could not list the tags either, after {why}")
    rows = tag_rows(repo, [{"name": n} for n in sorted(names, key=parts, reverse=True)])
    # git has no flag for a prerelease, so the name says it: -rc.1, -rc1, .pre, _RC1.
    # With `\b` after the word, `-rc1` was a release: no word ends between c and 1.
    for row in rows:
        row["prerelease"] = bool(re.search(r"[-._](rc|alpha|beta|pre|dev|preview)(?![a-z])", row["version"], re.IGNORECASE))
    return rows


def from_github(repo):
    """Releases newest first, falling back to tags for a project that tags only
    — with gh or without it: without the fallback a tags-only project read as
    "nothing published" on a machine with no gh, and the report said to stop
    watching it. When the API refuses altogether, the tags are asked of git."""
    if shutil_which("gh"):
        done = subprocess.run(
            ["gh", "api", f"repos/{repo}/releases?per_page=50"],
            check=False, capture_output=True, text=True, timeout=call_timeout(30),
        )
        if done.returncode == 0:
            releases = json.loads(done.stdout)
            if releases:
                return [
                    {
                        "version": r.get("tag_name", ""),
                        "at": release_day(r),
                        "title": r.get("name") or r.get("tag_name", ""),
                        "notes": r.get("body") or "",
                        "url": r.get("html_url", ""),
                        "prerelease": bool(r.get("prerelease")),
                    }
                    for r in releases
                ]
            tags = subprocess.run(
                ["gh", "api", f"repos/{repo}/tags?per_page=30"],
                check=False, capture_output=True, text=True, timeout=call_timeout(30),
            )
            if tags.returncode == 0:
                return tag_rows(repo, json.loads(tags.stdout))
            raise Unreachable(f"{repo}: neither releases nor tags could be read")
        return tags_with_git(repo, done.stderr.strip()[:80] or "the API refused")
    try:
        data = fetch_json(f"https://api.github.com/repos/{repo}/releases?per_page=50")
    except (urllib.error.URLError, http.client.HTTPException, OSError) as err:
        return tags_with_git(repo, f"the API said {str(err)[:60]}")
    if not data:
        return tag_rows(repo, fetch_json(f"https://api.github.com/repos/{repo}/tags?per_page=30"))
    return [
        {"version": r.get("tag_name", ""), "at": release_day(r),
         "title": r.get("name") or r.get("tag_name", ""), "notes": r.get("body") or "",
         "url": r.get("html_url", ""), "prerelease": bool(r.get("prerelease"))}
        for r in data
    ]


def from_pointer(url):
    """A release channel's own version pointer: the address the tool's updater
    reads, with one version on it. Claude Code's native install answers
    .../claude-code-releases/stable with the version in plain text, and grok's
    stable channel is https://x.ai/cli/stable. This is the channel a worker CLI
    was installed on, not a registry's newest: npm's newest grok was the alpha
    channel while stable was 1.0.62 (2026-10-21). A pointer that answers JSON
    with a version is read too, and a body with prose is searched for the one
    version in it."""
    text = fetch_text(url).strip()
    version = ""
    try:
        data = json.loads(text)
    except ValueError:
        data = None
    if isinstance(data, dict):
        for key in ("version", "stable_version", "tag_name", "tag"):
            value = data.get(key)
            if isinstance(value, str) and value.strip():
                version = value.strip()
                break
    elif isinstance(data, str):
        text = data.strip()
    if not version:
        found = re.search(r"(?<![a-z0-9])v?\d+(?:\.\d+)+(?:[-+][0-9a-z.-]+)?", text, re.IGNORECASE)
        if not found:
            raise Unreachable(f"{url} returned no version ({len(text)} characters)")
        version = found.group(0)
    return [{"version": version, "at": "", "title": version, "notes": "",
             "url": url, "prerelease": "-" in version.split("+", 1)[0]}]


def github_one(repo, path):
    """One object from the GitHub API, or None when there is none. Through gh
    when it is installed, since it carries the login; plain HTTPS otherwise."""
    try:
        if shutil_which("gh"):
            done = subprocess.run(["gh", "api", f"repos/{repo}/{path}"],
                                  check=False, capture_output=True, text=True, timeout=call_timeout(30))
            return json.loads(done.stdout) if done.returncode == 0 else None
        return fetch_json(f"https://api.github.com/repos/{repo}/{path}")
    except (OSError, ValueError, http.client.HTTPException, subprocess.TimeoutExpired):
        return None


def from_crates(name):
    data = fetch_json(f"https://crates.io/api/v1/crates/{name}")
    return [
        {"version": v.get("num", ""), "at": (v.get("created_at") or "")[:10],
         "title": v.get("num", ""), "notes": "",
         "url": f"https://crates.io/crates/{name}/{v.get('num','')}",
         "prerelease": "-" in v.get("num", "").split("+", 1)[0]}
        for v in data.get("versions", [])
    ]


def from_npm(name):
    """npm. A scoped package is @scope/name. The registry wants that slash
    written as %2F and the @ left as it is, or the request names a different
    package and comes back empty."""
    quoted = urllib.parse.quote(name, safe="@")
    data = fetch_json(f"https://registry.npmjs.org/{quoted}")
    times = data.get("time", {})
    versions = [v for v in data.get("versions", {})]
    versions.sort(key=lambda v: times.get(v, ""), reverse=True)
    return [
        {"version": v, "at": (times.get(v) or "")[:10], "title": v, "notes": "",
         "url": f"https://www.npmjs.com/package/{name}/v/{v}",
         "prerelease": "-" in v.split("+", 1)[0]}
        for v in versions
    ]


def from_brew(name):
    """Homebrew's formula API: the stable version `brew upgrade` would install.
    A formula publishes one stable version, not a history, so the list holds one
    row and `just upstream` has no notes for it. This is the source for a tool
    installed with brew whose own release pages are not what the formula builds:
    opencode's GitHub tags stopped at v1.19.3 while the formula built 2.1.2
    (2026-10-22)."""
    quoted = urllib.parse.quote(name, safe="@")
    data = fetch_json(f"https://formulae.brew.sh/api/formula/{quoted}.json")
    version = str((data.get("versions") or {}).get("stable") or "").strip()
    if not version:
        raise Unreachable(f"formulae.brew.sh lists no stable version for {name}")
    return [{"version": version, "at": "", "title": version, "notes": "",
             "url": f"https://formulae.brew.sh/formula/{name}",
             "prerelease": "-" in version.split("+", 1)[0]}]


def from_pub(name):
    """pub.dev, for Dart and Flutter. It lists oldest first, so this turns it
    round. A hyphen makes a prerelease; a `+1` is a build of a stable version.
    A version its author retracted is not one to follow, so it is left out."""
    data = fetch_json(f"https://pub.dev/api/packages/{name}")
    versions = [v for v in data.get("versions", []) if not v.get("retracted")]
    versions.sort(key=lambda v: v.get("published") or "", reverse=True)
    return [
        {"version": v.get("version", ""), "at": (v.get("published") or "")[:10],
         "title": v.get("version", ""), "notes": "",
         "url": f"https://pub.dev/packages/{name}/versions/{v.get('version','')}",
         "prerelease": "-" in v.get("version", "").split("+", 1)[0]}
        for v in versions
    ]


def from_pypi(name):
    """PyPI, for a tool installed with uv (just as rust-just, prek, graphifyy,
    uv itself). What is released here is what `uv tool upgrade` can install:
    graphify's GitHub tags said 1.0.0 while PyPI's newest was 0.9.67, and a
    watch read from GitHub reported as new what nobody could install
    (2026-09-25, spec 021). A release is dated by its first file; one whose
    files were all yanked is not one to follow. PEP 440 writes a prerelease
    with letters (1.0.0rc1, 2.0b3, 1.0.dev4), never with a hyphen."""
    data = fetch_json(f"https://pypi.org/pypi/{name}/json")
    out = []
    for version, files in (data.get("releases") or {}).items():
        if not files or all(f.get("yanked") for f in files):
            continue
        at = min((f.get("upload_time_iso_8601") or f.get("upload_time") or "") for f in files)[:10]
        out.append({"version": version, "at": at, "title": version, "notes": "",
                    "url": f"https://pypi.org/project/{name}/{version}/",
                    "prerelease": bool(re.search(r"\d(a|b|rc|c|dev|pre|alpha|beta)\d*", version, re.IGNORECASE))})
    out.sort(key=lambda r: r["at"], reverse=True)
    return out


def from_flutter(channel):
    """Flutter's own release list, because GitHub has none: the release pages of
    flutter/flutter stop at 3.19.0-0.1.pre, and 3.47.5 was out (2026-09-19). This
    file is what the archive page on flutter.dev is drawn from. There is one per
    operating system, with the same versions in each. A Mac's holds an x64 and
    an arm64 row per version, and a version built again has a pair per build
    (3.13.3: three, over five days), so a version is one row here, dated by the
    first day it existed. Nothing in it counts as a prerelease: on the beta
    channel a beta is the release, and the channel is the person's choice."""
    system = {"darwin": "macos", "win32": "windows"}.get(sys.platform, "linux")
    data = fetch_json(f"https://storage.googleapis.com/flutter_infra_release/releases/releases_{system}.json")
    rows = {}
    for r in data.get("releases", []):
        version, day = r.get("version", ""), (r.get("release_date") or "")[:10]
        if r.get("channel") != channel or not version:
            continue
        # The list carries no notes. The address is the CHANGELOG.md as it stood at
        # that version, which is where Flutter writes what each hotfix fixed.
        row = rows.setdefault(version, {
            "version": version, "at": day, "title": version,
            "notes": "(hotfixes: the CHANGELOG.md at that address; the release itself:"
                     " https://docs.flutter.dev/release/release-notes)",
            "url": f"https://github.com/flutter/flutter/blob/{version}/CHANGELOG.md",
            "prerelease": False})
        if day and (not row["at"] or day < row["at"]):
            row["at"] = day
    if not rows:
        have = sorted({r.get("channel") or "" for r in data.get("releases", [])} - {""})
        raise ValueError(f"no Flutter channel `{channel}`: the list has {', '.join(have) or 'none'}")
    return list(rows.values())


def from_hf(repo, pin=""):
    """Hugging Face, for a model a project pins by its revision: the commit it
    downloads. A model has commits, not versions, so the commits are the
    releases, newest first, and a pin is followed by the ones above it
    (spec 027). Measured on 2026-10-10: api/models/<owner>/<name>/commits/main
    lists them newest first with id, title and date, fifty a page (?p=0, 1,
    ...; a model of 109 commits answered 50, 50 and 9); pages are read until
    the pin is among them, twenty at most. A gated or private model answers
    401 without a token: HF_TOKEN is sent when it is set, and the 401 says so.
    The version shown is the commit's first twelve characters; the whole id is
    kept for matching a pin written longer."""
    token = os.environ.get("HF_TOKEN", "").strip()
    headers = {"User-Agent": "ai-backbone"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    pin = str(pin).strip().lower()
    out = []
    for page in range(20):
        try:
            data = fetch_json(f"https://huggingface.co/api/models/{repo}/commits/main"
                              + (f"?p={page}" if page else ""), headers)
        except urllib.error.HTTPError as err:
            if err.code == 401:
                raise ValueError(f"{repo}: Hugging Face answered 401, so the model is gated or private"
                                 + ("; HF_TOKEN was sent and is not enough" if token else "; set HF_TOKEN to read it")) from err
            raise
        if not isinstance(data, list):
            # ValueError on purpose: main() catches it and prints the sentence.
            # TypeError would leave that handler and become a traceback.
            raise ValueError(  # noqa: TRY004
                f"{repo}: Hugging Face answered something that is not a list of commits")
        out += [
            {"version": (c.get("id") or "")[:12], "commit": c.get("id") or "",
             "at": (c.get("date") or "")[:10], "title": c.get("title") or "",
             "notes": "\n\n".join(t for t in (c.get("title") or "", (c.get("message") or "").strip()) if t),
             "url": f"https://huggingface.co/{repo}/commit/{c.get('id', '')}", "prerelease": False}
            for c in data if isinstance(c, dict)
        ]
        if len(data) < 50 or (len(pin) >= 7 and any(r["commit"].lower().startswith(pin) for r in out)):
            break
    return out


# Kinds whose versions are commits, matched by the id's first characters.
# hf: is a model. ghcommit: is a repository that publishes no release: what
# moves is the default branch, and a version comparison would read the pin as
# unknown forever.
COMMIT_KINDS = {"hf", "ghcommit"}


def github_get(repo, path):
    """One JSON value from the GitHub API. Through gh when it is installed,
    since it carries the login; plain HTTPS otherwise, with no name and no
    token. gh's refusal is the answer: the same call without it would be
    refused too, and a second try spends a limit the first call already used."""
    if shutil_which("gh"):
        try:
            done = subprocess.run(
                ["gh", "api", f"repos/{repo}/{path}"],
                check=False, capture_output=True, text=True, timeout=call_timeout(30),
            )
        except (OSError, subprocess.TimeoutExpired) as err:
            raise Unreachable(f"{repo}: {err}") from err
        if done.returncode != 0:
            why = (done.stderr or done.stdout or "the API refused").strip().splitlines()
            raise Unreachable(f"{repo}: {(why[0] if why else 'the API refused')[:120]}")
        try:
            return json.loads(done.stdout)
        except ValueError as err:
            raise Unreachable(f"{repo}: the API answered something that is not JSON") from err
    return fetch_json(f"https://api.github.com/repos/{repo}/{path}")


def _commit_row(repo, item):
    """One commit from the GitHub API, in the shape the other sources use.
    None when the object has no id: a hole in the page is not a version."""
    if not isinstance(item, dict):
        return None
    sha = item.get("sha") or ""
    if not sha:
        return None
    commit = item.get("commit") or {}
    message = (commit.get("message") or "").strip()
    when = commit.get("committer") or commit.get("author") or {}
    return {
        "version": sha[:12],
        "commit": sha,
        "at": (when.get("date") or "")[:10],
        "title": message.split("\n", 1)[0],
        "notes": message,
        "url": item.get("html_url") or f"https://github.com/{repo}/commit/{sha}",
        "prerelease": False,
    }


def from_ghcommit(repo, pin=""):
    """Commits on the repository's default branch, newest first. For a project
    that publishes no release and no tag: the pin is a commit id, and each
    commit after it is one newer. The request names no branch. Naming `main`
    would miss a repository whose default branch is something else, and the
    commits API's own default is that branch. Pages of thirty until the pin is
    among them, twenty at most, so a pin that has fallen off the first page
    is still found."""
    pin = str(pin).strip().lower()
    out = []
    for page in range(1, 21):
        data = github_get(repo, f"commits?per_page=30&page={page}")
        if not isinstance(data, list):
            raise ValueError(  # noqa: TRY004
                f"{repo}: GitHub answered something that is not a list of commits")
        for item in data:
            row = _commit_row(repo, item)
            if row:
                out.append(row)
        if len(data) < 30 or (len(pin) >= 7 and any(r["commit"].lower().startswith(pin) for r in out)):
            break
    return out


def by_commit(entry):
    """Whether a row's versions are commits, so its pin is a commit id and is
    matched by its first characters, not compared as a number."""
    return entry.get("source", "").partition(":")[0] in COMMIT_KINDS


def commits_after(entry, releases):
    """For a row pinned by commit: the commits listed above the pinned one, the
    pinned one's date, and why there is no answer when it is not listed. A pin
    is the id or its first seven characters or more, as a revision is written."""
    pin = str(entry.get("pin", "")).strip().lower()
    for i, release in enumerate(releases):
        if len(pin) >= 7 and release.get("commit", release["version"]).lower().startswith(pin):
            return releases[:i], release["at"], ""
    if not releases:
        return [], "", "lists no commits"
    if len(pin) < 7:
        return [], "", f"pin {pin} is too short: a pin is a commit id, seven characters or more"
    return [], "", (f"lists no commit {pin} among its last {len(releases)}; the newest is"
                    f" {releases[0]['version']}")


def shown(path):
    """A path as the person's shell writes it: with / on Windows too, where Python
    writes C:\\...\\x and Git Bash, the shell the recipes run in, reads C:/.../x
    (spec 020)."""
    return path.replace(os.sep, "/") if os.sep != "/" else path


def shutil_which(name):
    from shutil import which
    return which(name)


# Where the version starts inside a tag: at the first number that begins a word,
# with or without a `v`. The 2 in `h2tools` does not begin one, the 0 in `rust-v0.155.1`
# and in `python/h2tools-core/v0.1.1` does. A date is tried first, so that the hyphens
# of 2026-07-28 are not read as the start of a suffix. An underscore joins numbers
# too, because PostgreSQL writes REL_17_2.
VERSION = re.compile(r"(?<![a-z0-9])(?<![0-9][._])v?(\d{4}-\d\d-\d\d(?!\d)|\d+(?:[._]\d+)*)")
# A version glued to its word, as in go1.24.0 and FFmpeg's n7.1: tried second, and only with a dot in it, so h2tools stays a word.
GLUED = re.compile(r"(?<![0-9._])(\d+(?:[._]\d+)+)")
DATED = re.compile(r"(?<![a-z0-9])v?\d{2,4}-\d\d-\d\d(?!\d)")


def shape(version):
    """A tag in two pieces: the label before the version, and the version as
    something that sorts. Three real repositories, read on 2026-09-19, are why
    there is a label at all. google/A2UI tags its sub-packages by path, and
    `python/h2tools-agent-sdk/v0.6.0` is not the next version of a pin of `v0.9`.
    openai/codex tags `rust-v0.155.1` beside `python-v…` and `rusty-v8-v…`; the
    numbers were looked for before the first hyphen, none of those tags has any
    there, and the row compared the words instead. The MCP specification tags by
    date, and `2026-07-28-RC` read as 2026 with a suffix of 07-28-RC, newer than
    `2026-07-28`. So the label is whatever stands before the version, and a tag
    under another label is another thing, never the pin's next version.

    The numbers sort as numbers, so 3.10 is after 3.9, and `1.0` is `1.0.0`:
    trailing zeros are dropped, or a pin written short is older than itself. A
    suffix like `-rc.8` sorts before the same numbers without one, which is what
    a release candidate means. A number inside a suffix is a number, with a dot
    before it or not: read as text, rc.10 sorted before rc.9 and the tenth
    release candidate was never seen. A word sorts after a number, as semver has
    it. `+build` is cut: a build of a version, not a version."""
    text = str(version).strip().lower().split("+", 1)[0]
    found = VERSION.search(text) or GLUED.search(text)
    if not found:
        return text, ([], 1, ())
    numbers = [int(n) for n in re.findall(r"\d+", found.group(1))]
    while numbers and numbers[-1] == 0:
        numbers.pop()
    suffix = tuple((0, int(p), "") if p.isdigit() else (1, 0, p)
                   for p in re.findall(r"\d+|[a-z]+", text[found.end():]))
    # No suffix sorts last: (numbers, 1, ()) beats (numbers, 0, rc.8).
    return text[:found.start()], (numbers, 0 if suffix else 1, suffix)


def parts(version):
    """A version as something that sorts; see shape()."""
    return shape(version)[1]


def newer_than(pin, releases, want_prereleases):
    """What the source lists that is newer than the pin, under the pin's own
    label: `rust-v0.156.0` follows a pin of `rust-v0.155.0` and nothing else does."""
    label, mine = shape(pin)
    out = []
    for release in releases:
        if not release["version"]:
            continue
        if release["prerelease"] and not want_prereleases:
            continue
        try:
            theirs, number = shape(release["version"])
        except ValueError:
            continue
        dated = bool(DATED.search(release["version"].lower())) == bool(DATED.search(str(pin).lower()))
        if theirs == label and number > mine and dated:
            out.append(release)
    return out


def tagged(entry, releases):
    """A source that spells its versions its own way, read the way the pin is
    written. PostgreSQL tags REL_18_6 while a compose file says postgres:18.6:
    with `tag = "REL_{major}_{minor}"` the row keeps its pinned_in, and every tag
    of that shape reads as 18.6. A tag of another shape is another thing, and
    is left out. Without `tag`, the releases are as the source listed them."""
    pattern = str(entry.get("tag") or "")
    if not pattern:
        return releases
    names = re.findall(r"\{(major|minor|patch)\}", pattern)
    if not names:
        raise ValueError(f"tag = \"{pattern}\" names no {{major}}, {{minor}} or {{patch}}")
    regex = re.compile("^" + "".join(
        r"(\d+)" if re.fullmatch(r"\{(major|minor|patch)\}", piece) else re.escape(piece)
        for piece in re.split(r"(\{(?:major|minor|patch)\})", pattern) if piece) + "$")
    out = []
    for release in releases:
        found = regex.match(release["version"])
        if not found:
            continue
        got = dict(zip(names, found.groups()))
        version = ".".join(got[k] for k in ("major", "minor", "patch") if k in got)
        out.append({**release, "version": version, "tag": release["version"]})
    # A pattern no tag fits is a typo in the list, not a source with nothing
    # published: said, with the pattern, so the reader can fix it.
    if releases and not out:
        raise ValueError(f"no tag the source lists looks like tag = \"{pattern}\"; numbers only,"
                         f" so a release candidate never does (the newest tag is {releases[0]['version']})")
    return out


def matched(entry, releases):
    """Drop releases whose version does not match `filter`, a regex.

    A stable line (nginx 1.30, not mainline 1.31) is the row's filter, not a
    sentence in `check` (n-8e5451). A pattern that matches nothing the source
    listed is said, the same way a tag pattern that fits no tag is said."""
    pattern = str(entry.get("filter") or "")
    if not pattern:
        return releases
    try:
        regex = re.compile(pattern)
    except re.error as err:
        raise ValueError(f"filter = \"{pattern}\" is not a pattern ({err})") from err
    out = [r for r in releases if r.get("version") and regex.search(str(r["version"]))]
    if releases and not out:
        newest = releases[0].get("version") or "?"
        raise ValueError(f"no version the source lists matches filter = \"{pattern}\";"
                         f" the newest tag is {newest}")
    return out


def tag_of(entry, version):
    """The tag a version of this row is written as at the source."""
    pattern = str(entry.get("tag") or "")
    if not pattern:
        return version
    numbers = str(version).lstrip("vV").split(".")
    keys = ("major", "minor", "patch")
    return re.sub(r"\{(major|minor|patch)\}",
                  lambda m: numbers[keys.index(m.group(1))] if keys.index(m.group(1)) < len(numbers) else "0",
                  pattern)


def same_major(pin, releases):
    """For a row with `major = true`: whether the source lists any release of the
    pinned major under the pin's own label. A major written alone (docker-v29)
    is current when v29.4.1 is listed; asked for 29 itself, it read UNKNOWN when
    the window of fifty held no 29.0.0 (a repository that also tags its
    sub-modules fills it)."""
    label, mine = shape(pin)
    return any(shape(r["version"])[0] == label and shape(r["version"])[1][0][:1] == mine[0][:1]
               for r in releases if r["version"] and not r["prerelease"])


def new_majors(pin, releases):
    """For a row with `major = true`: the pin is a major version that takes its
    own updates, as a workflow's `actions/checkout@v7` runs every v7.x
    (spec 021). Only a new major is news there."""
    mine = parts(str(pin))[0][:1]
    return [r for r in releases if parts(r["version"])[0][:1] > mine]


def unanswered(pin, releases):
    """Why a list with nothing newer in it is still no answer; "" when it is one.
    The release pages of flutter/flutter stop at 3.19.0-0.1.pre, and a pin of
    3.44.0 read "current, nothing newer" while 3.47.2 to 3.47.5 existed
    (2026-09-19): nothing listed was newer, so nothing was. "Current" is said
    only of a pin the source itself lists. A window of fifty releases that holds
    only prereleases nobody asked to count is the same case. The other one is a
    pin written another way than the source writes its versions (0.155.0 where
    the tags say rust-v0.155.0): no tag can follow it, and the reason shows the
    commonest way the source writes one. It says "if", because a window of
    fifty can also be full of another package's releases."""
    mine = shape(pin)
    versions = [r["version"] for r in releases if r["version"]]
    if any(shape(v) == mine for v in versions):
        return ""
    kin = [v for v in versions if shape(v)[0] == mine[0]]
    if kin:
        return f"lists neither {pin} nor a release newer than it; the newest it lists is {max(kin, key=parts)}"
    plain = [r["version"] for r in releases if r["version"] and not r["prerelease"]] or versions
    usual = collections.Counter(shape(v)[0] for v in plain).most_common(1)[0][0]
    like = max((v for v in plain if shape(v)[0] == usual), key=parts)
    return (f"lists nothing written like {pin}; its versions look like {like}:"
            " if that is what is pinned, write the pin that way")


def released_at(entry, releases, known="", ask=True):
    """The day the pinned version itself came out — not the newest one, the one
    this project runs on. From what the source listed when it is there; a tag
    may carry a v the pin does not, or the other way round. A date learned in an
    earlier week (`known`) is kept, since it does not change. Only then does a
    GitHub pin older than the fifty fetched cost one more call per tag form,
    and a project that tags without releasing answers with the commit's date.
    `ask` is false when this run is showing the shared copy: that extra call is
    the online check, and a second project must not pay it."""
    pin = str(entry.get("pin", "")).strip()
    for release in releases:
        if release["version"].lstrip("vV") == pin.lstrip("vV") and release["at"]:
            return release["at"]
    kind, _, repo = entry.get("source", "").partition(":")
    if known or kind != "github" or not pin or OFFLINE or not ask:
        return known
    tags = list(dict.fromkeys([tag_of(entry, pin)] if entry.get("tag") else
                              [pin, "v" + pin.lstrip("vV"), pin.lstrip("vV")]))
    for tag in tags:
        found = github_one(repo, f"releases/tags/{tag}")
        if found and release_day(found):
            return release_day(found)
    for tag in tags:
        found = github_one(repo, f"commits/{tag}")
        if found:
            return (found.get("commit", {}).get("committer", {}).get("date") or "")[:10]
    return ""


def where(entry):
    """Where the pinned version itself can be read on this machine. Paths, not
    prose: the answer to "what does this version do" is in its source, not in
    anybody's memory of the version before."""
    kind, _, rest = entry.get("source", "").partition(":")
    name = entry.get("name") or rest
    pin = str(entry.get("pin", "")).strip()
    bare = pin.lstrip("vV")
    out = []
    if entry.get("docs"):
        out.append(("docs", entry["docs"]))
    elif kind == "crates" and bare:
        out.append(("docs", f"https://docs.rs/{rest}/{bare}"))
    elif kind == "pub" and bare:
        out.append(("docs", f"https://pub.dev/documentation/{rest}/{bare}/"))
    elif kind == "hf" and pin:
        out.append(("docs", f"https://huggingface.co/{rest}/tree/{pin}"))
    elif kind == "ghcommit" and pin:
        out.append(("docs", f"https://github.com/{rest}/commit/{pin}"))
    if entry.get("pinned_in"):
        if pin_is_real(entry):
            out.append(("pinned in", entry["pinned_in"]))
        else:
            out.append(("listed in", f"{entry['pinned_in']}   (does not hold {pin or 'a pin'})"))
    folders = []
    if kind == "hf" and pin:
        # Where the Hugging Face libraries keep a downloaded revision.
        hub = Path(os.environ.get("HF_HUB_CACHE")
                   or Path(os.environ.get("HF_HOME") or Path.home() / ".cache" / "huggingface") / "hub")
        folders += sorted(glob.glob(str(hub / f"models--{rest.replace('/', '--')}" / "snapshots"
                                        / (glob.escape(pin) + "*"))))
    elif bare and kind not in COMMIT_KINDS:
        cargo = Path(os.environ.get("CARGO_HOME") or Path.home() / ".cargo")
        crate = rest if kind == "crates" else name
        folders += sorted(glob.glob(str(cargo / "registry" / "src" / "*" / glob.escape(f"{crate}-{bare}"))))
    if kind == "pub" and bare:
        # Where `dart pub get` and `flutter pub get` keep what they download.
        pub = Path(os.environ.get("PUB_CACHE") or Path.home() / ".pub-cache")
        if (pub / "hosted" / "pub.dev" / f"{rest}-{bare}").is_dir():
            folders.append(str(pub / "hosted" / "pub.dev" / f"{rest}-{bare}"))
    near = Path(entry.get("pinned_in") or ".").parent / "node_modules" / (rest if kind == "npm" else name)
    if near.is_dir():
        folders.append(str(near))
    if shutil_which("uv"):
        tools = said(["uv", "tool", "dir"])
        if tools and Path(tools, name).is_dir():
            folders.append(str(Path(tools, name)))
    # A model, and a repository watched by its commits, is no program: a binary
    # that shares its name says nothing about it.
    exe = None if kind in COMMIT_KINDS else shutil_which("flutter" if kind == "flutter" else name)
    repo = {"github": rest, "ghcommit": rest, "flutter": "flutter/flutter"}.get(kind)
    sdk = checkout(exe, repo) if exe and repo else ""
    if sdk:
        folders.append(sdk)
    for folder in folders:
        held = holds(folder)
        out.append(("source", f"{folder}/" + (f"   (holds {held}, not the pin)" if held and parts(held) != parts(pin) else "")))
        for log in sorted(glob.glob(f"{glob.escape(folder)}/CHANGELOG*")):
            out.append(("notes", log))
    if exe:
        out.append(("on PATH", f"{exe}   {said([exe, '--version'])[:60]}".rstrip()))
    return out


def checkout(exe, repo):
    """The git checkout a command runs from, when it is a clone of the watched
    repository itself. An SDK that updates itself in place is one: Flutter on
    this Mac is a clone of flutter/flutter in /opt/homebrew/share/flutter, with
    its CHANGELOG.md, standing at whatever tag it was last moved to (3.47.5
    under a pin of 3.44.0, measured 2026-09-19). The address it was cloned from
    is what decides, because walking up from any Homebrew command ends in
    /opt/homebrew, which is a git repository too: Homebrew's own. Read from the
    config as it was written: `git remote get-url` answers after rewriting."""
    here = Path(os.path.realpath(exe)).parent
    for folder in (here, *here.parents):
        if (folder / ".git").exists():
            origin = said(["git", "-C", str(folder), "config", "--get", "remote.origin.url"])
            mine = re.search(rf"github\.com[:/]{re.escape(repo)}(\.git)?/?$", origin, re.IGNORECASE)
            return str(folder) if mine else ""
    return ""


def said(command):
    """The first line a command printed, or nothing. Five seconds and no
    keyboard: a binary that happens to be named like a watch must not be able
    to hold `just upstream <name>` for as long as it likes."""
    try:
        done = subprocess.run(command, check=False, capture_output=True, text=True, timeout=call_timeout(5),
                              stdin=subprocess.DEVNULL)
    except (OSError, subprocess.SubprocessError):
        return ""
    return ((done.stdout or done.stderr).strip().splitlines() or [""])[0].strip()


def holds(folder):
    """What version a folder holds, where it can quietly hold something other
    than the pin: a node_modules folder says it in its package.json, and a git
    checkout stands at a tag. A cargo folder is named by its version, and a tool
    on PATH says its own."""
    try:
        return str(json.loads(Path(folder, "package.json").read_text()).get("version", ""))
    except (OSError, ValueError, AttributeError):
        pass
    if not Path(folder, ".git").exists():
        return ""
    # `said` hands back what git complained of as readily as a tag; a tag has no space.
    tag = said(["git", "-C", str(folder), "tag", "--points-at", "HEAD"])
    return "" if " " in tag else tag


def cached_dates():
    """What earlier runs learned: {name: {pin, at}}. Empty for no cache, a cache
    from before 3.20.0, or one that cannot be read."""
    try:
        held = json.loads(CACHE.read_text()).get("released", {})
    except (OSError, ValueError, AttributeError):
        return {}
    return held if isinstance(held, dict) else {}


def pin_is_real(entry):
    """Whether the file the list says holds this pin still holds it. A watch
    list that has drifted from the code is worse than no watch list. The pin has
    to stand there as a version of its own: asked as "is this text anywhere in
    the file", 1.38.2 was held by a lockfile that had moved on to 1.38.20, and
    MOVED was never said. A pin written with its label, because that is how the
    source tags it (rust-v0.155.0), is also held by a file that says 0.155.0, and
    a pin written with a v (v2.11.4) by one that says 2.11.4, as an image tag
    does (image: x:2.11.4-alpine)."""
    where = entry.get("pinned_in")
    if not where:
        return None
    path = Path(where)
    pin = str(entry.get("pin", "")).strip()
    if not pin or not path.is_file():
        return False
    text = path.read_text(errors="ignore")
    # A commit id is held by the id, or by a longer one it begins: hex on both sides.
    if by_commit(entry):
        return bool(re.search(rf"(?<![0-9a-f]){re.escape(pin.lower())}", text.lower()))
    label = shape(pin)[0]
    forms = {pin, pin[len(label):].lstrip("vV")} if label else {pin}
    # Only a version with a dot: the bare 7 of a major pin (v7) would be held by
    # any lone 7 in the file, a `cap: 7` or ubuntu-24.04's 24 alike.
    if re.match(r"[vV]\d+\.\d", pin):
        forms.add(pin[1:])
    return any(re.search(rf"(?<![0-9])(?<![0-9]\.){re.escape(form)}(?![0-9])", text) for form in forms if form)


SOURCES = {"github": from_github, "crates": from_crates, "npm": from_npm, "pub": from_pub,
           "pypi": from_pypi, "flutter": from_flutter, "hf": from_hf, "ghcommit": from_ghcommit,
           "pointer": from_pointer, "brew": from_brew}


def look(entry):
    """A source this script cannot read is said first, online or not: a typo in
    the list is the reader's to fix, and offline mode must not hide it."""
    source = entry.get("source", "")
    kind, _, rest = source.partition(":")
    if kind not in SOURCES or not rest:
        raise ValueError(f"unknown source `{source}` — use github:owner/repo, crates:, npm:, pub:,"
                         " pypi:, flutter:stable, hf:owner/name, ghcommit:owner/repo, brew:name, pointer:url")
    if OFFLINE:
        raise Unreachable("offline: AI_BACKBONE_OFFLINE is set")
    if kind in COMMIT_KINDS:
        return SOURCES[kind](rest, entry.get("pin", ""))
    return SOURCES[kind](rest)


def share_root():
    """Where this machine keeps one answer per source. The suite points it at a
    temp folder; `XDG_CACHE_HOME` is honoured the way the advisory database is."""
    override = os.environ.get("AI_BACKBONE_UPSTREAM_CACHE")
    if override:
        return Path(override)
    base = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache")
    return base / "ai-backbone" / "upstream"


def cache_key(entry):
    """The shared file's name. Two projects that watch the same source share one
    lookup. A commit row is read only until its own pin, so the pin is part of
    that key: a newer pin must not hide the commits an older one needs."""
    source = entry.get("source", "")
    if source.partition(":")[0] in COMMIT_KINDS:
        return source + " pin=" + str(entry.get("pin", "")).strip()
    return source


def share_file(key):
    slug = re.sub(r"[^A-Za-z0-9._+-]+", "_", key).strip("_") or "source"
    digest = hashlib.sha256(key.encode()).hexdigest()[:12]
    return share_root() / f"{slug}--{digest}.json"


def _parse_time(text):
    if not text or not isinstance(text, str):
        return None
    try:
        when = datetime.datetime.fromisoformat(text)
    except ValueError:
        return None
    if when.tzinfo is None:
        when = when.replace(tzinfo=datetime.timezone.utc)
    return when


def _now_iso():
    return datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat()


def share_read(key):
    try:
        data = json.loads(share_file(key).read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None
    if not isinstance(data, dict) or data.get("source") != key:
        return None
    if not isinstance(data.get("releases"), list):
        return None
    return data


def _share_write(key, record):
    path = share_file(key)
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(record, indent=1) + "\n", encoding="utf-8")
    os.replace(tmp, path)


def share_ok(key, releases):
    _share_write(key, {"source": key, "fetched": _now_iso(), "releases": releases,
                       "error": "", "detail": "", "failed_at": ""})


def share_fail(key, previous, reason, detail):
    prev = previous or {}
    text = " ".join(str(detail).split())[:140]
    # The word is what the next run and the report both look for. An HTTP 403
    # says "Forbidden" and not "rate limit"; the body was read once, already.
    if reason and reason not in text.lower():
        text = f"{reason}: {text}"[:160]
    _share_write(key, {
        "source": key,
        "fetched": prev.get("fetched") or "",
        "releases": prev.get("releases") or [],
        "error": reason,
        "detail": text,
        "failed_at": _now_iso(),
    })


def share_recent(record, now=None):
    """True when the last try, success or failure, was under a day ago."""
    moments = [t for t in (_parse_time(record.get("failed_at")), _parse_time(record.get("fetched"))) if t]
    if not moments:
        return False
    now = now or datetime.datetime.now(datetime.timezone.utc)
    return (now - max(moments)).total_seconds() < SHARE_DAY


def share_usable(record, refresh):
    """A copy this run may show without asking. A rate limit and a check that
    ran out of time are the day's answer. Offline, and a source that did not
    answer, are asked again: the network may be back."""
    if refresh or not record or not share_recent(record):
        return False
    if not record.get("error"):
        return True
    return record.get("error") in ("rate-limited", "slow")


def age_phrase(record):
    """How old the last successful answer is, in words. The failure's own time
    is not this: a rate limit an hour ago can be sitting on a result from
    yesterday, and the row is that result."""
    when = _parse_time((record or {}).get("fetched"))
    if when is None:
        return "no earlier result"
    hours = int((datetime.datetime.now(datetime.timezone.utc) - when).total_seconds() // 3600)
    if hours < 1:
        return "less than an hour ago"
    if hours == 1:
        return "1 hour ago"
    if hours < 48:
        return f"{hours} hours ago"
    days = hours // 24
    return "1 day ago" if days == 1 else f"{days} days ago"


def classify(err):
    """Why a lookup failed, in one word the report can say, and the sentence."""
    detail = " ".join(str(err).split())[:160]
    blob = detail.lower()
    if isinstance(err, urllib.error.HTTPError):
        try:
            blob += " " + err.read().decode("utf-8", "replace").lower()
        except (OSError, ValueError, AttributeError):
            pass
        if err.code == 429 or "rate limit" in blob or "secondary rate" in blob:
            return "rate-limited", detail or "rate limit"
    if "rate limit" in blob or "rate-limited" in blob:
        return "rate-limited", detail or "rate limit"
    if "offline" in blob:
        return "offline", detail or "offline"
    # "slow" is the whole check running past its ten seconds, said by obtain
    # before it asks. One source that times out did not answer; the next
    # session asks it again, the way a dead network is asked again.
    if blob.startswith("slow"):
        return "slow", detail or "slow"
    return "unreachable", detail or "unreachable"


def _timed_out(err):
    """A call that used up its own seconds. Python 3.9's socket timeout is an
    OSError, and urllib wraps that as the reason of a URLError."""
    if isinstance(err, (subprocess.TimeoutExpired, TimeoutError, socket.timeout)):
        return True
    return isinstance(getattr(err, "reason", None), (TimeoutError, socket.timeout))


def _after_fail(key, err):
    """The previous answer when there is one; otherwise the error `look` raised,
    unchanged, so a source that does not answer still counts toward the three
    that stop the rest of the list."""
    record = share_read(key)
    if record and record.get("releases"):
        return record["releases"], record.get("error") or "unreachable", False
    raise err


def _take_refresh(argv):
    """`--refresh` asks every source again. It may sit before or after a name."""
    refresh = False
    rest = []
    for arg in argv:
        if arg == "--refresh":
            refresh = True
        else:
            rest.append(arg)
    return refresh, rest


def obtain(entry, refresh, deadline):
    """Releases for this row, whether they are an old result, and whether this
    call asked the source. The old-result word is "" when the answer is from
    today. It is offline, rate-limited, slow or unreachable when this run
    wanted a new answer, could not have one, and is showing the previous one.
    With nothing saved, the error is raised the way `look` raises it.
    `deadline` also caps the call already in flight: one source's thirty
    seconds must not spend a session's ten, and that timeout counts as slow."""
    global CALL_DEADLINE
    previous = CALL_DEADLINE
    if deadline is not None:
        CALL_DEADLINE = deadline
    try:
        return _obtain(entry, refresh, deadline)
    finally:
        CALL_DEADLINE = previous


def _obtain(entry, refresh, deadline):
    key = cache_key(entry)
    kind, _, rest = entry.get("source", "").partition(":")
    if kind not in SOURCES or not rest:
        return look(entry), "", True
    record = share_read(key)
    if share_usable(record, refresh):
        # An empty list is an answer (nothing published). A failure with nothing
        # saved is not: say why, and do not ask again when the day is used up.
        if record.get("error") and not record.get("releases"):
            raise Unreachable(record.get("detail") or record.get("error") or "unreachable")
        return list(record.get("releases") or []), record.get("error") or "", False
    if deadline is not None and time.monotonic() >= deadline:
        detail = "slow: the check ran past 10 seconds"
        share_fail(key, record, "slow", detail)
        return _after_fail(key, Unreachable(detail))
    try:
        releases = look(entry)
    except (OSError, ValueError, http.client.HTTPException,
            subprocess.TimeoutExpired, Unreachable) as err:
        reason, detail = classify(err)
        if CALL_DEADLINE is not None and _timed_out(err):
            reason, detail = "slow", "slow: the check ran past 10 seconds"
        share_fail(key, record, reason, detail)
        return _after_fail(key, err)
    share_ok(key, releases)
    return releases, "", True


def read_list():
    """The watch list, or None after saying why not. TOML is imported here and
    not at the top: it arrived in Python 3.11 and a Mac's own python3 is 3.9,
    where the import was a traceback that session-start threw away, so the
    weekly check had silently never run there."""
    try:
        import tomllib
    except ModuleNotFoundError:
        say(f"Needs Python 3.11 or newer for tomllib; this is {sys.version.split()[0]}."
            " uv can put one on this machine: uv python install 3.13")
        return None
    try:
        watched = tomllib.loads(LIST.read_text()).get("watch", [])
    except (OSError, ValueError) as err:
        say(f"{LIST} could not be read: {err}")
        return None
    if not isinstance(watched, list) or not all(isinstance(e, dict) for e in watched):
        say(f"{LIST}: each thing watched is its own [[watch]] block, with two brackets.")
        return None
    # `pin = 1.0` without quotes is a number to TOML; here it is always text.
    for entry in watched:
        if "pin" in entry:
            entry["pin"] = str(entry["pin"]).strip()
    return watched


def recent():
    """Every session, without the network, from what the daily check cached: what
    the project is built on and which of those pins came out in the last twelve
    months. Read with tomllib where the interpreter has it; a Mac with only its
    own python3 gets the pins from the cache, and the lines, not a nag."""
    if not LIST.is_file():
        return 0
    cached = cached_dates()
    try:
        import tomllib
        watched = tomllib.loads(LIST.read_text()).get("watch", [])
        if not isinstance(watched, list) or not all(isinstance(e, dict) for e in watched):
            return 0  # as below: `just upstream` says what is wrong with the list
        pins = [(e.get("name") or e.get("source", "?"), str(e.get("pin", "?"))) for e in watched]
    except ModuleNotFoundError:
        pins = [(name, str(held.get("pin", "?"))) for name, held in cached.items() if isinstance(held, dict)]
    except (OSError, ValueError):
        return 0  # a list that cannot be read is `just upstream`'s to say
    if not pins:
        return 0
    say("Built on: " + " · ".join(f"{name} {pin}" for name, pin in pins) + f" ({LIST.as_posix()})")
    # A date belongs to a pin, not to a name: after the pin moves in the list,
    # last week's date is of another version and is not shown for this one.
    dated, undated = [], []
    for name, pin in pins:
        held = cached.get(name)
        at = held.get("at", "") if isinstance(held, dict) and held.get("pin") == pin else ""
        (dated if at else undated).append((at, name, pin))
    if not dated:
        say("Released in the last 12 months: not known yet. The daily check fills it in"
            " when the sources can be reached: just upstream")
        return 0
    since = (datetime.date.today() - datetime.timedelta(days=365)).isoformat()
    fresh = [f"{name} {pin} ({at})" for at, name, pin in sorted(dated, reverse=True) if at >= since]
    say("Released in the last 12 months: " + (", ".join(fresh) if fresh else "none."))
    if fresh:
        say("An agent whose training ended before one of those dates does not know that version."
            " Read it first: just upstream <name>")
    if undated:
        say("Release date not known yet: " + ", ".join(f"{name} {pin}" for _, name, pin in undated)
            + ". The daily check fills it in when the source can be reached.")
    return 0


# ─────────── every crate a Cargo.lock locks, against RustSec ───────────
#
#     upstream.py --advisories doctor  <Cargo.lock>...   everything, in doctor's columns
#     upstream.py --advisories session <Cargo.lock>...   only what is found, for session-start
#
# A workspace locks hundreds of crates, and a vulnerability published in one of
# them went unnoticed until someone happened to read it; a watch list follows a
# handful (spec 029). The database is RustSec's own (rustsec/advisory-db, the
# one cargo-audit and cargo-deny read), fetched as one archive of about half a
# megabyte with no name, no e-mail and no git: a person's git can be set to
# reach GitHub over their own SSH key, and this must not say who asks. It is
# kept for every project on this machine in ~/.cache/ai-backbone/advisory-db
# and fetched again when it is a day old. With no network, or with
# AI_BACKBONE_OFFLINE set, the copy that is here is used and its age is said.
# AI_BACKBONE_ADVISORY_DB names a folder to read instead, never fetched, and
# AI_BACKBONE_ADVISORY_URL the archive to fetch.
#
# A version is affected when no requirement in the advisory's `patched` and
# `unaffected` lists matches it. Requirements are read the way cargo reads them
# (a bare 1.2.3 is ^1.2.3, 1.2.* is =1.2), and versions are compared in plain
# order, pre-releases too, as OSV compares them: 0.9.0-alpha.1 is past a fix
# in 0.8.1 (cargo's rule for choosing a dependency would say it is not, and
# every session would print advice nobody can follow). Only crates from
# crates.io are read: a path or git crate of the same name is another crate.
# Withdrawn advisories are left out; `unmaintained`, `unsound` and `notice`
# ones are counted on a line of their own, since they are not vulnerabilities.
#
#     upstream.py --advisories gate [--triaged <file>] <Cargo.lock>...
#
# An advisory a project has looked at and ships anyway (only tests build the
# crate, a dependency pins it, the flaw does not touch how it is used) has a
# [[triaged]] row in docs/advisories.toml: id, crate, why, fixed and until
# (spec 030). session-start stays quiet about it and doctor lists it, until
# the day passes, until RustSec's fixed versions are no longer the row's
# `fixed` (a fix the project may now reach), or while the row cannot be used.
# A day is at most 90 ahead: a reason is true for a while, not for ever. The
# gate is a ship's question, asked of the files it is given and never of the
# folder it runs in: one line per advisory, 0 when every one is covered, 1
# when one is not, 2 when it could not tell. A database fetched more than 7
# days ago that cannot be fetched now is said and still read: it knows every
# advisory up to its date, and a release a GitHub outage can stop teaches
# people to switch the gate off.

ADV_URL = os.environ.get("AI_BACKBONE_ADVISORY_URL",
                     "https://codeload.github.com/rustsec/advisory-db/tar.gz/refs/heads/main")
ADV_DB = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache") / "ai-backbone" / "advisory-db"
ADV_STAMP = "ai-backbone.fetched"
ADV_DAY = 86400
ADV_STALE = 7 * ADV_DAY
# Text, not a Path: Windows would print a Path as docs\advisories.toml.
TRIAGE = "docs/advisories.toml"
TRIAGE_DAYS = 90
CRATES_IO = ("registry+https://github.com/rust-lang/crates.io-index", "sparse+https://index.crates.io/")


# ───────────── versions and requirements, as cargo reads them ─────────────

SEMVER = re.compile(r"^(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?(?:\+[0-9A-Za-z.-]+)?$")
SEMVER_REQ = re.compile(r"^(=|>=|<=|>|<|~|\^)?\s*(\*|\d+)(?:\.(\*|\d+))?(?:\.(\*|\d+))?(?:-([0-9A-Za-z.-]+))?(?:\+[0-9A-Za-z.-]+)?$")


def semver_pre(pre):
    """A pre-release sorts below its release; numeric parts below the others."""
    if not pre:
        return (1,)
    return (0,) + tuple((0, int(x), "") if x.isdigit() else (1, 0, x) for x in pre.split("."))


def semver(text):
    m = SEMVER.match(text.strip())
    if not m:
        return None
    return (int(m.group(1)), int(m.group(2)), int(m.group(3)), m.group(4) or "")


def semver_key(v):
    return (v[0], v[1], v[2], semver_pre(v[3]))


def semver_req(req):
    """A requirement as a list of (op, version, pre-release named) with the
    partial and wildcard forms spelled out; None when it cannot be read."""
    out = []
    for part in req.split(","):
        part = part.strip()
        if part == "*" or part == "":
            out.append((">=", (0, 0, 0, ""), False))
            continue
        m = SEMVER_REQ.match(part)
        if not m:
            return None
        op = m.group(1) or "^"
        nums = [m.group(2), m.group(3), m.group(4)]
        pre = m.group(5) or ""
        if nums[0] == "*":
            out.append((">=", (0, 0, 0, ""), False))
            continue
        # How many numbers were written before a wildcard or the end.
        n = 0
        for x in nums:
            if x is None or x == "*":
                break
            n += 1
        if "*" in nums and op == "^":
            op = "="  # 1.2.* is =1.2, never ^1.2
        a = [int(x) for x in nums[:n]] + [0] * (3 - n)
        lo = (a[0], a[1], a[2], pre)
        named = bool(pre)

        def up(i, base=a):
            b = base[:i] + [0] * (3 - i)
            b[i - 1] += 1
            return (b[0], b[1], b[2], "")

        if op == "=":
            if n == 3:
                out.append(("=", lo, named))
            else:
                out += [(">=", lo, named), ("<", up(n), False)]
        elif op == ">":
            out.append((">", lo, named) if n == 3 else (">=", up(n), False))
        elif op == ">=":
            out.append((">=", lo, named))
        elif op == "<":
            out.append(("<", lo, named))
        elif op == "<=":
            out.append(("<=", lo, named) if n == 3 else ("<", up(n), False))
        elif op == "~":
            out += [(">=", lo, named), ("<", up(min(n, 2)), False)]
        else:  # ^
            if a[0] > 0 or n == 1:
                hi = up(1)
            elif a[1] > 0 or n == 2:
                hi = up(2)
            else:
                hi = up(3)
            out += [(">=", lo, named), ("<", hi, False)]
    return out


def semver_matches(req, v):
    cs = semver_req(req)
    if cs is None:
        return False
    for op, c, _ in cs:
        k, ck = semver_key(v), semver_key(c)
        ok = {"=": k == ck, ">": k > ck, ">=": k >= ck, "<": k < ck, "<=": k <= ck}[op]
        if not ok:
            return False
    return True


# ───────────────────────────── the database ─────────────────────────────

def adv_fetch(db):
    """Fetch the archive into a new folder beside db and put it in db's place.
    Only crates/**/*.md is taken from it, and only by its plain name."""
    db.parent.mkdir(parents=True, exist_ok=True)
    request = urllib.request.Request(ADV_URL, headers={"User-Agent": "ai-backbone"})
    with urllib.request.urlopen(request, timeout=call_timeout(15)) as response:
        data = response.read()
    new = Path(tempfile.mkdtemp(prefix="advisory-db.", dir=db.parent))
    try:
        newest = 0
        with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as archive:
            for member in archive.getmembers():
                parts = member.name.split("/")
                # A name is taken only as plain words: no "..", and nothing that
                # Windows reads as a folder or a drive.
                if (not member.isfile() or len(parts) != 4 or parts[1] != "crates"
                        or not parts[3].endswith(".md") or any(p in ("", ".", "..") for p in parts)
                        or any(c in p for p in parts for c in "\\:")):
                    continue
                target = new / "crates" / parts[2] / parts[3]
                target.parent.mkdir(parents=True, exist_ok=True)
                extracted = archive.extractfile(member)
                if extracted is None:
                    continue
                target.write_bytes(extracted.read())
                newest = max(newest, int(member.mtime))
        if newest == 0:
            raise ValueError("the archive held no advisory")
        (new / ADV_STAMP).write_text(time.strftime("%Y-%m-%d", time.gmtime(newest)) + "\n")
        old = db.parent / f"{db.name}.old.{os.getpid()}"
        if db.exists():
            db.rename(old)
        try:
            new.rename(db)
        except OSError:
            # Another run put its copy there first; else the old one goes back.
            if not db.exists() and old.exists():
                old.rename(db)
        shutil.rmtree(old, ignore_errors=True)
    finally:
        shutil.rmtree(new, ignore_errors=True)


def adv_database():
    """The folder to read, its date, a note when it is not today's, and how
    many seconds ago it was fetched (None when nobody knows); or None and why."""
    given = os.environ.get("AI_BACKBONE_ADVISORY_DB")
    if given:
        db = Path(given)
        return (db, adv_date(db), "", None) if (db / "crates").is_dir() else (None, "", f"{db} holds no crates/ folder", None)
    db, note = ADV_DB, ""
    stamp = db / ADV_STAMP
    age = time.time() - stamp.stat().st_mtime if stamp.is_file() else None
    if age is None or age > ADV_DAY:
        if os.environ.get("AI_BACKBONE_OFFLINE"):
            note = "offline (AI_BACKBONE_OFFLINE)"
        else:
            try:
                adv_fetch(db)
                age = 0
            except Exception as err:  # noqa: BLE001 - said, never a traceback
                note = f"could not fetch it ({type(err).__name__})"
    if not (db / "crates").is_dir():
        return None, "", f"{note or 'nothing fetched yet'}, and there is no copy of the advisory database here", None
    if note and age is not None:
        note = f"{note}; the copy here was fetched {int(age // ADV_DAY)} day(s) ago"
    return db, adv_date(db), note, age


def adv_date(db):
    try:
        return (db / ADV_STAMP).read_text().strip()
    except OSError:
        return "?"


def adv_front(text):
    """The TOML block an advisory starts with."""
    m = re.search(r"```toml\s*\n(.*?)\n```", text, re.DOTALL)
    return m.group(1) if m else None


def adv_title(text):
    m = re.search(r"^#\s+(.+)$", text.split("```", 2)[-1], re.MULTILINE)
    return m.group(1).strip() if m else ""


def adv_list(db, name, tomllib):
    folder = db / "crates" / name
    if not folder.is_dir():
        return []
    out = []
    for f in sorted(folder.glob("*.md")):
        try:
            text = f.read_text(errors="replace")
            data = tomllib.loads(adv_front(text) or "")
        except (OSError, ValueError):
            continue
        adv = data.get("advisory", {})
        if adv.get("withdrawn") or adv.get("package") != name:
            continue
        versions = data.get("versions", {})
        out.append({"id": adv.get("id", f.stem), "kind": adv.get("informational") or "",
                    "patched": list(versions.get("patched", [])), "unaffected": list(versions.get("unaffected", [])),
                    "title": adv_title(text)})
    return out


def cargo_locked(lock, tomllib):
    """(name, version) of every crates.io package a Cargo.lock locks."""
    data = tomllib.loads(Path(lock).read_text())
    return sorted({(p["name"], p["version"]) for p in data.get("package", [])
                   if isinstance(p, dict) and str(p.get("source", "")).startswith(CRATES_IO)
                   and "name" in p and "version" in p})


class _Ambiguous(Exception):
    """A dependency edge that could call a shipped crate test-only."""


def _dep_crate(key, value, workspace_deps):
    """The crate name a dependency names. A rename (`package`) and a
    workspace spec are followed. Anything else is ambiguous."""
    if isinstance(value, str):
        return key
    if not isinstance(value, dict):
        raise _Ambiguous(key)
    if value.get("workspace") is True:
        spec = workspace_deps.get(key)
        if not isinstance(spec, (str, dict)):
            raise _Ambiguous(key)
        if isinstance(value.get("package"), str):
            return value["package"]
        if isinstance(spec, dict) and isinstance(spec.get("package"), str):
            return spec["package"]
        return key
    if isinstance(value.get("package"), str):
        return value["package"]
    if any(name in value for name in ("version", "path", "git")):
        return key
    raise _Ambiguous(key)


def _prod_names(data, workspace_deps, into):
    """Crate names from the tables a shipped build uses. Dev-dependencies
    are how a test-only crate is named, so they are not read."""
    for section in ("dependencies", "build-dependencies"):
        block = data.get(section, {})
        if not isinstance(block, dict):
            raise _Ambiguous(section)
        for key, value in block.items():
            into.add(_dep_crate(key, value, workspace_deps))
    targets = data.get("target", {})
    if not isinstance(targets, dict):
        raise _Ambiguous("target")
    for spec in targets.values():
        if not isinstance(spec, dict):
            raise _Ambiguous("target")
        for section in ("dependencies", "build-dependencies"):
            block = spec.get(section, {})
            if not isinstance(block, dict):
                raise _Ambiguous(section)
            for key, value in block.items():
                into.add(_dep_crate(key, value, workspace_deps))


def _member_dirs(root, data):
    ws = data.get("workspace")
    if not isinstance(ws, dict) or "members" not in ws:
        return [root]
    members, exclude = ws.get("members"), ws.get("exclude", [])
    if not isinstance(members, list) or not isinstance(exclude, list):
        raise _Ambiguous("members")
    found = []
    for pattern in members:
        if not isinstance(pattern, str):
            raise _Ambiguous("members")
        paths = sorted(p for p in root.glob(pattern) if p.is_dir()) if any(c in pattern for c in "*?[") else [root / pattern]
        if not paths:
            raise _Ambiguous(pattern)
        found.extend(paths)
    skipped = set()
    for pattern in exclude:
        if not isinstance(pattern, str):
            raise _Ambiguous("exclude")
        paths = [p for p in root.glob(pattern) if p.is_dir()] if any(c in pattern for c in "*?[") else [root / pattern]
        skipped.update(p.resolve() for p in paths)
    dirs, seen = [], set()
    if isinstance(data.get("package"), dict):
        dirs.append(root)
        seen.add(root)
    for path in found:
        path = path.resolve()
        if path in skipped or path in seen:
            continue
        if not (path / "Cargo.toml").is_file():
            raise _Ambiguous(str(path))
        seen.add(path)
        dirs.append(path)
    return dirs


def _resolve_dep(spec, by_name):
    parts = str(spec).split()
    if not parts:
        raise _Ambiguous("empty")
    cands = by_name.get(parts[0], [])
    if len(parts) == 1:
        if len(cands) != 1:
            raise _Ambiguous(parts[0])
        return cands[0]
    version = parts[1]
    source = parts[2][1:-1] if len(parts) >= 3 and parts[2].startswith("(") and parts[2].endswith(")") else None
    matched = [p for p in cands if p["version"] == version and (source is None or p.get("source") == source)]
    if len(matched) != 1:
        raise _Ambiguous(spec)
    return matched[0]


def production_reached(lock):
    """(name, version) of every locked crate a shipped build reaches, read
    from the Cargo.toml files beside the lock. None when there is no manifest
    or an edge is ambiguous: no label then, never a guess (spec 030, n-3140d5)."""
    lock = Path(lock)
    root = lock.parent.resolve()
    manifest = root / "Cargo.toml"
    if not manifest.is_file():
        return None
    try:
        import tomllib
    except ModuleNotFoundError:
        return None
    try:
        data = tomllib.loads(manifest.read_text())
        ws = data.get("workspace")
        workspace_deps = ws.get("dependencies", {}) if isinstance(ws, dict) else {}
        if not isinstance(workspace_deps, dict):
            return None
        names = set()
        for member in _member_dirs(root, data):
            member_data = data if member == root else tomllib.loads((member / "Cargo.toml").read_text())
            _prod_names(member_data, workspace_deps, names)
        locked = tomllib.loads(lock.read_text())
    except (OSError, ValueError, _Ambiguous):
        return None
    by_name = {}
    for pkg in locked.get("package", []):
        if not isinstance(pkg, dict) or not isinstance(pkg.get("name"), str) or not isinstance(pkg.get("version"), str):
            return None
        deps = pkg.get("dependencies", [])
        if not isinstance(deps, list) or not all(isinstance(item, str) for item in deps):
            return None
        row = {"name": pkg["name"], "version": pkg["version"], "source": str(pkg.get("source", "")), "deps": deps}
        by_name.setdefault(pkg["name"], []).append(row)
    seen = set()
    wave = []
    for rows in by_name.values():
        for row in rows:
            if row["name"] in names:
                seen.add((row["name"], row["version"]))
                wave.append(row)
    try:
        while wave:
            pkg = wave.pop()
            for spec in pkg["deps"]:
                nxt = _resolve_dep(spec, by_name)
                key = (nxt["name"], nxt["version"])
                if key in seen:
                    continue
                seen.add(key)
                wave.append(nxt)
    except _Ambiguous:
        return None
    return seen


def test_only_note(lock, name, ver, cache):
    """The label, or nothing. Never silences the finding."""
    if lock not in cache:
        cache[lock] = production_reached(lock)
    reached = cache[lock]
    if reached is None or (name, ver) in reached:
        return ""
    return " (only tests, by Cargo.toml)"


def adv_check(lock, db, tomllib):
    """Vulnerabilities and notices for one Cargo.lock, and how many crates."""
    crates = cargo_locked(lock, tomllib)
    found, notices = [], []
    for name, ver in crates:
        v = semver(ver)
        if v is None:
            continue
        for adv in adv_list(db, name, tomllib):
            if any(semver_matches(r, v) for r in adv["patched"] + adv["unaffected"]):
                continue
            if adv["kind"]:
                notices.append((adv["kind"], name))
            else:
                found.append((name, ver, adv))
    return crates, found, notices


# ─────────────────── what a project has looked at (spec 030) ───────────────────

def adv_fix(patched):
    """The fixed versions as every line says them; a row's `fixed` copies the
    part after "fixed in", or says none."""
    return f"fixed in {' or '.join(patched)}" if patched else "no fixed version yet"


def fixed_set(value):
    """A row's `fixed`, or an advisory's list, as something to compare: spaces
    and order do not count, and none is nothing."""
    parts = value if isinstance(value, list) else re.split(r"\s+or\s+", str(value).strip())
    return frozenset(re.sub(r"\s+", "", str(p)) for p in parts) - {"", "none"}


def crate_key(name):
    return str(name).strip().lower().replace("_", "-")


def one_line(text, most=200):
    """A person's text on one line of a page, whatever they typed."""
    text = re.sub(r"[\x00-\x1f\x7f]+", " ", str(text)).strip()
    return text if len(text) <= most else text[:most - 1] + "…"


def triage_day(value):
    if isinstance(value, datetime.datetime):
        return value.date()
    if isinstance(value, datetime.date):
        return value
    try:
        return datetime.date.fromisoformat(str(value).strip())
    except ValueError:
        return None


def triage_read(path, tomllib, today):
    """The rows of a triage file by advisory id, each with the fault that keeps
    it from counting, and how many rows name no id. Raises OSError or
    ValueError when the file cannot be read as one."""
    rows = tomllib.loads(Path(path).read_text()).get("triaged", [])
    if not isinstance(rows, list) or not all(isinstance(r, dict) for r in rows):
        raise ValueError("each advisory is its own [[triaged]] block, with two brackets")
    out, loose = {}, 0
    last = today + datetime.timedelta(days=TRIAGE_DAYS)
    for row in rows:
        rid = str(row.get("id", "")).strip()
        if not rid:
            loose += 1
            continue
        until = triage_day(row.get("until", ""))
        fault = ""
        if not str(row.get("why", "")).strip():
            fault = "it has no why"
        elif "fixed" not in row:
            fault = 'it has no fixed (what doctor prints after "fixed in", or none)'
        elif until is None:
            fault = "its until is not a date (YYYY-MM-DD)"
        elif until > last:
            fault = f"its until {until} is more than {TRIAGE_DAYS} days ahead; {last} at most"
        # The first row of an id is the one read; a second is a copy someone forgot.
        out.setdefault(rid, {"crate": str(row.get("crate", "")).strip(), "why": one_line(row.get("why", "")),
                             "fixed": row.get("fixed", ""), "until": until, "fault": fault})
    return out, loose


def adv_judge(name, adv, rows, today):
    """What a found advisory is now: triaged, untriaged, expired, changed (the
    fixed versions moved since the row) or invalid, and the words why."""
    row = rows.get(adv["id"])
    if row is None:
        return "untriaged", ""
    fault = row["fault"]
    if not fault and crate_key(row["crate"]) != crate_key(name):
        fault = f"it names the crate {row['crate'] or '(none)'}, and the advisory is about {name}"
    if fault:
        return "invalid", fault
    if row["until"] < today:
        return "expired", f"triaged until {row['until']}"
    if fixed_set(row["fixed"]) != fixed_set(adv["patched"]):
        was = " or ".join(map(str, row["fixed"])) if isinstance(row["fixed"], list) else row["fixed"]
        return "changed", f"triaged with fixed = \"{one_line(was, 80) or 'none'}\""
    return "triaged", f"triaged until {row['until']}"


def advisories(mode, locks):
    """doctor's lines, or session-start's finding, for these Cargo.lock files."""
    try:
        import tomllib
    except ModuleNotFoundError:
        if mode == "doctor":
            print(f"  --    Cargo.lock not read against RustSec: needs Python 3.11 or newer for tomllib, this is"
                  f" {sys.version.split()[0]} -> uv python install 3.13")
        return 0
    db, day, note, _ = adv_database()
    if db is None:
        # Said by doctor; a session that cannot read it has nothing to report.
        if mode == "doctor":
            print(f"  warn  Cargo.lock not read against RustSec: {note}")
        return 0
    lines, rows, loose, today = [], {}, 0, datetime.date.today()
    if Path(TRIAGE).is_file():
        try:
            rows, loose = triage_read(TRIAGE, tomllib, today)
        except (OSError, ValueError) as err:
            lines.append(("warn", f"{TRIAGE} could not be read, so nothing in it counts: {one_line(err)}"))
    seen, unread, usage = set(), False, {}
    for lock in locks:
        try:
            crates, found, notices = adv_check(lock, db, tomllib)
        except (OSError, ValueError, KeyError, TypeError) as err:
            lines.append(("warn", f"{lock} could not be read: {err}"))
            unread = True
            continue
        triaged = 0
        for name, ver, adv in found:
            seen.add(adv["id"])
            note = test_only_note(lock, name, ver, usage)
            state, why = adv_judge(name, adv, rows, today)
            if state == "triaged":
                triaged += 1
                lines.append(("info", f"{lock}: {name} {ver}{note} has {adv['id']}, {why}: {rows[adv['id']]['why']}"))
                continue
            said = {"untriaged": "", "expired": f"; {why}, which has passed",
                    "changed": f"; {why}, and RustSec's fixed versions have moved",
                    "invalid": f"; its row in {TRIAGE} does not count: {why}"}[state]
            lines.append(("warn", (f"{lock}: {name} {ver}{note} has {adv['id']}, {adv['title']} -> {adv_fix(adv['patched'])}"
                                   f"{said} (https://rustsec.org/advisories/{adv['id']})")))
        if len(found) == triaged:
            beyond = f" beyond the {triaged} triaged in {TRIAGE}" if triaged else ""
            lines.append(("ok", f"{lock}: no RustSec advisory for its {len(crates)} crate{'' if len(crates) == 1 else 's'}{beyond}"))
        if notices:
            kinds = {}
            for kind, name in notices:
                kinds.setdefault(kind, []).append(name)
            said = "; ".join(f"{k}: {', '.join(sorted(set(v)))}" for k, v in sorted(kinds.items()))
            lines.append(("info", f"{lock}: notices, not vulnerabilities ({said})"))
    # A row nothing needs any more: the crate was updated past the fix, or left.
    # Not said when a lock could not be read: its advisories are not known.
    if not unread:
        for rid, row in rows.items():
            if rid not in seen:
                lines.append(("info", f"{TRIAGE}: {rid} ({row['crate'] or 'no crate'}) is in no Cargo.lock any more -> remove the row"))
    if loose:
        lines.append(("info", f"{TRIAGE}: {loose} [[triaged]] row(s) with no id count for nothing -> the advisory's id, or remove"))
    when = f"database of {day}" + (f", {note}" if note else "")
    if mode == "doctor":
        for kind, line in lines:
            print(f"  {kind:<5} {line}")
        print(f"        RustSec {when}")
    else:
        warns = [line for kind, line in lines if kind == "warn"]
        if warns:
            # Five at most: the page an agent reads first has room for little.
            print(f"=== RUST ADVISORIES ({len(warns)}; RustSec {when}) ===")
            for line in warns[:5]:
                print(f"- {line}")
            if len(warns) > 5:
                print(f"  ... and {len(warns) - 5} more: just doctor")
    return 0


def package_dirs():
    """Every folder the project holds a package.json in, node_modules and the
    folders that are not the project's own left out. os.walk, not glob: a
    dependency tree is tens of thousands of folders and must not be entered."""
    out = []
    for base, dirs, files in os.walk("."):
        dirs[:] = sorted(d for d in dirs if d not in NPM_SKIP)
        if "package.json" in files:
            out.append(os.path.normpath(base))
    return out


def npm_call(folder, args, seconds):
    """One npm call, its answer as text. Through temporary files, not pipes: a
    child npm started that outlives its parent must not hold this session on a
    pipe that never closes. The return code is npm's; 1 means "found something"
    for both outdated and audit, not a failure."""
    env = dict(os.environ)
    env.update({"NO_UPDATE_NOTIFIER": "1", "npm_config_update_notifier": "false",
                "npm_config_fund": "false", "npm_config_progress": "false",
                "npm_config_audit": "false"})
    with tempfile.TemporaryFile(mode="w+", encoding="utf-8") as out, \
            tempfile.TemporaryFile(mode="w+", encoding="utf-8") as err:
        done = subprocess.run(["npm", *args], cwd=folder, stdout=out, stderr=err,
                              text=True, timeout=max(seconds, 0.05), env=env)
        out.seek(0)
        return done.returncode, out.read()


def _npm_count(value):
    try:
        return int(value or 0)
    except (TypeError, ValueError):
        return 0


def npm_check():
    """npm outdated and npm audit for every package.json a project holds, next
    to the RustSec check. Quiet when there is none, and only findings or a
    could-not-check line when there is one. A slow or failing npm is one line:
    it never holds the session, and npm is never run for a folder that has no
    lock file to audit."""
    folders = package_dirs()
    if not folders:
        return 0
    deadline = time.monotonic() + NPM_BUDGET
    lines, missing = [], False
    for folder in folders:
        where = "." if folder == "." else folder[2:] if folder.startswith("./") else folder
        if time.monotonic() >= deadline:
            lines.append(f"npm: {where}: could not check (slow: the npm check ran out of time)")
            continue
        try:
            code, text = npm_call(folder, ["outdated", "--json"],
                                  min(NPM_TIMEOUT, deadline - time.monotonic()))
        except subprocess.TimeoutExpired:
            lines.append(f"npm: {where}: could not check outdated (slow)")
        except FileNotFoundError:
            missing = True
            break
        except OSError as err:
            lines.append(f"npm: {where}: could not check outdated ({one_line(err)})")
        else:
            if code not in (0, 1):
                lines.append(f"npm: {where}: could not check outdated (npm said {code})")
            else:
                try:
                    data = json.loads(text or "{}")
                except ValueError:
                    data = None
                if not isinstance(data, dict):
                    lines.append(f"npm: {where}: could not check outdated (npm's answer was not JSON)")
                elif data:
                    names = sorted(data)
                    shown = ", ".join(
                        f"{n} {str((data[n] or {}).get('current') or '?')} →"
                        f" {str((data[n] or {}).get('latest') or '?')}" for n in names[:3])
                    more = f" and {len(names) - 3} more" if len(names) > 3 else ""
                    lines.append(f"npm: {where}: {len(names)} outdated ({shown}{more})")
        lock = Path(folder) / "package-lock.json"
        if not lock.is_file() and not (Path(folder) / "npm-shrinkwrap.json").is_file():
            continue
        if time.monotonic() >= deadline:
            lines.append(f"npm: {where}: could not check audit (slow: the npm check ran out of time)")
            continue
        try:
            code, text = npm_call(folder, ["audit", "--json"],
                                  min(NPM_TIMEOUT, deadline - time.monotonic()))
        except subprocess.TimeoutExpired:
            lines.append(f"npm: {where}: could not check audit (slow)")
        except FileNotFoundError:
            missing = True
            break
        except OSError as err:
            lines.append(f"npm: {where}: could not check audit ({one_line(err)})")
        else:
            try:
                data = json.loads(text or "{}")
            except ValueError:
                data = None
            meta = data.get("metadata", {}).get("vulnerabilities") if isinstance(data, dict) else None
            if not isinstance(meta, dict):
                why = f"npm said {code}" if code not in (0, 1) else "npm's answer was not JSON"
                lines.append(f"npm: {where}: could not check audit ({why})")
            elif _npm_count(meta.get("total")) > 0:
                parts = [f"{_npm_count(meta[k])} {k}"
                         for k in ("critical", "high", "moderate", "low", "info")
                         if _npm_count(meta.get(k))]
                lines.append(f"npm: {where}: {_npm_count(meta.get('total'))} vulnerabilities"
                             f" ({', '.join(parts)}) -> npm audit")
    if missing:
        lines.append("npm: could not check (npm is not installed)")
    if not lines:
        return 0
    say(f"=== NPM PACKAGES ({len(folders)}) ===")
    for line in lines[:12]:
        say(line)
    if len(lines) > 12:
        say(f"  ... and {len(lines) - 12} more: npm outdated; npm audit")
    return 0


def advisories_gate(args):
    """A ship's question for these Cargo.lock files: is every advisory in them
    one the triage file covers? One line per advisory and lock, its state first;
    no title and no reason, nothing the caller did not hand in. 0 yes, 1 no, 2
    could not tell (spec 030)."""
    triage, locks, i = None, [], 0
    while i < len(args):
        if args[i] == "--triaged" and i + 1 < len(args):
            triage, i = args[i + 1], i + 2
        else:
            locks.append(args[i])
            i += 1
    if not locks:
        print("error no Cargo.lock given: upstream.py --advisories gate [--triaged <file>] <Cargo.lock>...")
        return 2
    try:
        import tomllib
    except ModuleNotFoundError:
        print(f"error needs Python 3.11 or newer for tomllib, this is {sys.version.split()[0]}")
        return 2
    rows, today = {}, datetime.date.today()
    if triage is not None:
        # A project with no file yet has nothing triaged: stricter, never looser.
        if not Path(triage).exists():
            print(f"note {triage} does not exist, so nothing is triaged")
        else:
            try:
                rows, _ = triage_read(triage, tomllib, today)
            except (OSError, ValueError) as err:
                print(f"error {triage} could not be read: {one_line(err)}")
                return 2
    db, day, note, age = adv_database()
    if db is None:
        print(f"error no RustSec database to read: {note}")
        return 2
    worst, usage = 0, {}
    for lock in locks:
        try:
            crates, found, _ = adv_check(lock, db, tomllib)
        except (OSError, ValueError, KeyError, TypeError) as err:
            print(f"error {lock} could not be read: {one_line(err)}")
            worst = 2
            continue
        for name, ver, adv in found:
            state, why = adv_judge(name, adv, rows, today)
            note = test_only_note(lock, name, ver, usage)
            print(f"{state} {lock}: {name} {ver}{note} {adv['id']} -> {adv_fix(adv['patched'])}" + (f" ({why})" if why else ""))
            if state != "triaged":
                worst = max(worst, 1)
        if not found:
            print(f"ok {lock}: no advisory for its {len(crates)} crate{'' if len(crates) == 1 else 's'}")
    if age is not None and age > ADV_STALE:
        print(f"stale RustSec database of {day}, {note or f'fetched {int(age // ADV_DAY)} days ago'}")
    else:
        print(f"database RustSec of {day}" + (f", {note}" if note else ""))
    return worst


def crate_sources(locks):
    """doctor's lines for a row that reads from GitHub what a Cargo.lock locks
    as a crate (spec 029). A crate's release reaches crates.io whether or not it
    gets a tag, and a github: row missed four patch releases that got none.
    Quiet when there is nothing to say, or nothing to read it with."""
    try:
        import tomllib
        watched = tomllib.loads(LIST.read_text()).get("watch", [])
    except (ModuleNotFoundError, OSError, ValueError):
        return 0
    crates = {}
    for lock in locks:
        try:
            packages = tomllib.loads(Path(lock).read_text()).get("package", [])
        except (OSError, ValueError):
            continue
        for p in packages:
            if isinstance(p, dict) and isinstance(p.get("name"), str) and str(p.get("source", "")).startswith(CRATES_IO):
                crates[p["name"].lower().replace("_", "-")] = p["name"]
    for entry in watched if isinstance(watched, list) else []:
        source = str(entry.get("source", "")) if isinstance(entry, dict) else ""
        if not source.startswith("github:"):
            continue
        repo = source.split(":", 1)[1].rstrip("/").rsplit("/", 1)[-1]
        for name in (str(entry.get("name", "")), repo):
            crate = crates.get(name.lower().replace("_", "-"))
            if crate:
                say(f"  warn  {LIST} reads {entry.get('name') or repo} from {source}, and Cargo.lock locks the crate"
                    f" {crate}: a release that gets no GitHub tag is missed -> source = \"crates:{crate}\","
                    " with the pin as crates.io writes it")
                break
    return 0


def backbone_version():
    """The version on the first line of the core.just beside this script."""
    path = Path(__file__).resolve().parent / "core.just"
    try:
        first = path.read_text(encoding="utf-8").splitlines()[0]
    except (OSError, IndexError):
        return "?"
    found = re.search(r"version (\d+\.\d+\.\d+)", first)
    return found.group(1) if found else "?"


# The tools `just tools-update` moves itself. Any other pin is a job, done in
# the session or handed to a worker, and never an upgrade this script runs.
OWN_TOOLS = {"just", "prek", "graphify", "uv"}


def _is_idea(entry):
    return str(entry.get("kind", "")).strip() == "idea"


def survey(watched, refresh, deadline, only=""):
    """One pass over the watch list. `deadline` is a monotonic time after which
    no new source is asked; None waits, which is what `just upstream` does.
    The rows are what the table prints: name, pin, released, newest, how, real."""
    found = {}
    rows = []
    whynot = {}
    unlisted = set()
    stale = []
    held = []
    before = cached_dates()
    silent = 0
    live_any = False
    for entry in watched:
        name = entry.get("name") or entry.get("source", "?")
        if only and only != name:
            continue
        # A network that accepts and never answers cost one wait per row: five
        # minutes of silence at the start of a session on a list of thirteen.
        # Three sources in a row that do not answer, and the rest are not asked.
        if silent >= 3:
            whynot[name] = "not asked: three sources in a row did not answer"
            rows.append((name, entry.get("pin", "?"), "?", "?", "unreachable", pin_is_real(entry)))
            continue
        # A source not read this week keeps the date an earlier week learned, as
        # long as the pin is the same one: a week behind a proxy, or offline,
        # must not blank an answer that does not change.
        held_date = before.get(name)
        known = held_date.get("at", "") if isinstance(held_date, dict) and held_date.get("pin") == entry.get("pin", "?") else ""
        try:
            got, old, live = obtain(entry, refresh, deadline)
            releases = matched(entry, tagged(entry, got))
        except (OSError, ValueError, http.client.HTTPException,
                subprocess.TimeoutExpired, Unreachable) as err:
            # The reason goes to `whynot`, not into the table: it is a sentence,
            # the column is twelve wide, and a row that overflows takes the
            # column the summary below reads from with it. What a proxy answers
            # can be a page long; what this script says is one line. The pin is
            # checked all the same: that needs the file, not the network.
            whynot[name] = " ".join(str(err).split())[:160]
            # A refusal (404, 403) is an answer: the network works. Only silence counts.
            if isinstance(err, subprocess.TimeoutExpired) or (
                    isinstance(err, OSError) and not isinstance(err, urllib.error.HTTPError)):
                silent += 1
            rows.append((name, entry.get("pin", "?"), known or "?", "?", "unreachable", pin_is_real(entry)))
            continue
        silent = 0
        record = share_read(cache_key(entry)) or {}
        if old:
            stale.append((name, old, record))
        elif not live:
            held.append(record)
        if live:
            live_any = True
        if by_commit(entry):
            ahead, at, silence = commits_after(entry, releases)
            at = at or known or "?"
            if silence:
                whynot[name] = silence
                unlisted.add(name)
                rows.append((name, entry.get("pin", "?"), at, "?", "unknown", pin_is_real(entry)))
                continue
            found[name] = {"entry": entry, "ahead": ahead}
            rows.append((name, entry.get("pin", "?"), at, ahead[0]["version"] if ahead else "—",
                         f"{len(ahead)} newer" if ahead else "current", pin_is_real(entry)))
            continue
        at = released_at(entry, releases, known, ask=live) or "?"
        if not releases:
            rows.append((name, entry.get("pin", "?"), at, "nothing published", "unknown", pin_is_real(entry)))
            continue
        ahead = newer_than(entry.get("pin", "0"), releases, entry.get("prereleases", False))
        if entry.get("major"):
            ahead = new_majors(entry.get("pin", "0"), ahead)
        # Nothing newer is "current" only when the source lists the pin itself,
        # or, for a major row, a release of that major.
        listed = entry.get("major") and same_major(entry.get("pin", "0"), releases)
        silence = "" if ahead or listed else unanswered(entry.get("pin", "0"), releases)
        if silence:
            whynot[name] = silence
            unlisted.add(name)
            rows.append((name, entry.get("pin", "?"), at, "?", "unknown", pin_is_real(entry)))
            continue
        found[name] = {"entry": entry, "ahead": ahead}
        rows.append((
            name,
            entry.get("pin", "?"),
            at,
            ahead[0]["version"] if ahead else "—",
            f"{len(ahead)} newer" if ahead else "current",
            pin_is_real(entry),
        ))
    return {"rows": rows, "whynot": whynot, "unlisted": unlisted, "stale": stale,
            "found": found, "live": live_any, "held": held}


def fresh_header(live_any, held_ok, stale, whynot=None):
    """When the block was checked. A copy under a day old is that time. A run
    that could not check says how old the last answer is, and why."""
    now = datetime.datetime.now(datetime.timezone.utc)
    reasons = []
    for _name, reason, _record in stale:
        if reason and reason not in reasons:
            reasons.append(reason)
    # A failure with nothing saved never becomes a stale row. The sentence is
    # still why, and the header says the short word rather than "no answer".
    if not reasons:
        for text in (whynot or {}).values():
            low = text.lower()
            word = next((w for w in ("offline", "rate-limited", "slow", "unreachable") if w in low), "")
            if word and word not in reasons:
                reasons.append(word)
    times = []
    for record in list(held_ok) + [item[2] for item in stale]:
        when = _parse_time((record or {}).get("fetched"))
        if when:
            times.append(when)
    when = now if live_any or not times else max(times)
    stamp = when.astimezone().strftime("%Y-%m-%d %H:%M")
    if not reasons and (live_any or times):
        return f"=== FRESHNESS (checked {stamp}) ==="
    if not times:
        why = ", ".join(reasons) if reasons else "no answer"
        return f"=== FRESHNESS (checked {stamp}, no earlier result; {why}) ==="
    phrase = age_phrase({"fetched": min(times).replace(microsecond=0).isoformat()})
    why = ", ".join(reasons) if reasons else "no answer"
    return f"=== FRESHNESS (checked {stamp}, {phrase}; {why}) ==="


def first_job(behind, moved, ideas):
    """One job. Something behind comes before a drifted pin, and a drifted pin
    before an idea to read. Nothing here upgrades anything."""
    if behind:
        name, pin, newest = behind[0]
        change = f"{name} ({pin} → {newest})"
        if name in OWN_TOOLS:
            return (f"update {change}: just tools-update, then just save."
                    " Nothing is upgraded on its own.")
        worker = os.environ.get("WORKER", "").strip().lower()
        if worker and worker != "off":
            return (f"update {change}. WORKER is {worker}: hand it over with"
                    " just delegate, do not do it here. Nothing is upgraded on its own.")
        return f"update {change}. Do it in this session. Nothing is upgraded on its own."
    if moved:
        return f"fix the pin for {moved[0]}: the file no longer holds it."
    if ideas:
        return (f"read {ideas[0][0]}: ten lines on what is new and what it means."
                " The maintainer hears it only when it is worth a decision.")
    return "none"


def print_fresh(watched, report):
    """The FRESHNESS block. An idea's newer release is 'to read', never behind."""
    by_name = {(e.get("name") or e.get("source", "?")): e for e in watched}
    behind, moved, ideas = [], [], []
    for name, pin, _at, newest, how, real in report["rows"]:
        entry = by_name.get(name, {})
        if real is False:
            moved.append(name)
        if _is_idea(entry):
            if str(how).endswith("newer"):
                ideas.append((name, pin, newest, str(entry.get("look_for") or "").strip()))
            continue
        if str(how).endswith("newer"):
            behind.append((name, pin, newest))
    say(fresh_header(report["live"], report["held"], report["stale"], report["whynot"]))
    if behind:
        say("Behind: " + ", ".join(f"{name} {pin} → {newest}" for name, pin, newest in behind))
    else:
        say("Behind: nothing")
    say("MOVED: " + (", ".join(moved) if moved else "nothing"))
    say(f"Backbone: {backbone_version()}")
    if ideas:
        parts = []
        for name, pin, newest, look in ideas:
            bit = f"{name} {pin} → {newest}"
            if look:
                bit += f" ({look})"
            parts.append(bit)
        say("To read: " + ", ".join(parts))
    else:
        say("To read: nothing")
    if report["whynot"]:
        say("Could not check: " + "; ".join(f"{name} ({report['whynot'][name]})" for name in report["whynot"]))
    say("First job: " + first_job(behind, moved, ideas))
    return [name for name, _pin, _newest in behind], moved


def write_project_cache(rows, behind, moved):
    """The per-project cache `just projects` and `--recent` read. Ideas are not
    put in `behind`: a newer idea is something to read, not something to upgrade."""
    if not CACHE.parent.is_dir():
        return
    released = {name: {"pin": pin, "at": "" if at == "?" else at} for name, pin, at, *_ in rows}
    CACHE.write_bytes(json.dumps({"behind": behind, "moved": moved, "released": released}, indent=1).encode("utf-8"))


def _fresh_empty(why):
    stamp = datetime.datetime.now().astimezone().strftime("%Y-%m-%d %H:%M")
    say(f"=== FRESHNESS (checked {stamp}, no earlier result; {why}) ===")
    say("Behind: nothing")
    say("MOVED: nothing")
    say(f"Backbone: {backbone_version()}")
    say("To read: nothing")
    say(f"Could not check: {why}")
    say("First job: none")


def freshness():
    """What session start shows. Always returns 0: offline, rate-limited or
    past the ten seconds is a line in the block, and the session goes on."""
    global CALL_DEADLINE
    deadline = time.monotonic() + FRESH_BUDGET
    previous = CALL_DEADLINE
    CALL_DEADLINE = deadline
    try:
        if not LIST.is_file():
            _fresh_empty(f"no {LIST}. Run: just upstream-init")
            return 0
        watched = read_list()
        if watched is None:
            return 0
        if not watched:
            _fresh_empty(f"{LIST} watches nothing yet")
            return 0
        report = survey(watched, False, deadline, "")
        behind, moved = print_fresh(watched, report)
        write_project_cache(report["rows"], behind, moved)
        return 0
    finally:
        CALL_DEADLINE = previous


def main():
    # Before the list is read, and so before tomllib: these lines need neither.
    if len(sys.argv) > 1 and sys.argv[1] == "--recent":
        return recent()
    if len(sys.argv) > 1 and sys.argv[1] == "--freshness":
        return freshness()
    if len(sys.argv) > 1 and sys.argv[1] == "--crate-sources":
        return crate_sources(sys.argv[2:])
    if len(sys.argv) > 2 and sys.argv[1] == "--advisories" and sys.argv[2] == "gate":
        return advisories_gate(sys.argv[3:])
    if len(sys.argv) > 1 and sys.argv[1] == "--npm":
        return npm_check()
    if len(sys.argv) > 3 and sys.argv[1] == "--advisories" and sys.argv[2] in ("doctor", "session"):
        return advisories(sys.argv[2], sys.argv[3:])
    if not LIST.is_file():
        say(f"No {LIST}. Run: just upstream-init")
        return 0
    watched = read_list()
    if watched is None:
        return 1
    if not watched:
        say(f"{LIST} watches nothing yet. Add a [[watch]] block per thing this project is built on.")
        return 0

    refresh, rest = _take_refresh(sys.argv[1:])
    if any(a.startswith("-") for a in rest):
        bad = next(a for a in rest if a.startswith("-"))
        say(f"Unknown option {bad}. The option is --refresh.")
        return 1
    if len(rest) > 1:
        say("Name one thing to read, or pass --refresh.")
        return 1
    only = rest[0] if rest else ""
    report = survey(watched, refresh, None, only)
    rows, whynot, unlisted, stale, found = (
        report["rows"], report["whynot"], report["unlisted"], report["stale"], report["found"])

    if only:
        # Looked up in the list, not in what answered: a name whose source was
        # silent used to be told it "is not in" the list it was sitting in.
        entry = next((e for e in watched if (e.get("name") or e.get("source", "?")) == only), None)
        if entry is None:
            say(f"`{only}` is not in {LIST}.")
            return 1
        held_old = next((item for item in stale if item[0] == only), None)
        if held_old:
            say(f"Last result, {age_phrase(held_old[2])} ({held_old[1]}).")
        say(f"== {only}: pinned at {entry.get('pin')} — {entry.get('why', '')}")
        at = rows[0][2] if rows else "?"
        say(f"   released {at}" if at != "?" else "   released: not known")
        if entry.get("check"):
            say(f"   on an upgrade, check: {entry['check']}")
        say(f"   where {entry.get('pin')} itself can be read on this machine:")
        places = where(entry)
        for what, path in places:
            say(f"     {what:<10} {shown(path)}")
        if not places:
            say("     (not found on this machine)")
        held = found.get(only)
        if not held and only in unlisted:
            say(f"   the source was read, and it {whynot[only]}")
            return 0
        if not held:
            say(f"   the source could not be read: {whynot.get(only, 'nothing came back')}")
            # 0, as the table is when nothing answered: what is on this machine was
            # said above, and that is what was asked for. 1 is for a name that is
            # not in the list.
            return 0
        ahead = held["ahead"]
        if not ahead:
            say("   nothing newer.")
            return 0
        for release in ahead[:8]:
            say()
            say(f"-- {release['version']}  {release['at']}  {release['url']}")
            notes = (release["notes"] or "").strip()
            say(notes[:4000] if notes else "   (no notes published)")
        if len(ahead) > 8:
            say(f"\n   … and {len(ahead) - 8} more.")
        return 0

    # As wide as what is in them: `16.4.0-canary.361125` ran into the next column.
    wn, wp, wv = (max(16, 2 + max(len(str(row[i])) for row in rows)) for i in (0, 1, 3))
    say("  " + f"{'watched':<{wn}}{'pinned':<{wp}}{'released':<12}{'newest':<{wv}}{'':<12}pin")
    for name, pin, at, newest, how, real in rows:
        mark = "ok" if real else ("MOVED" if real is False else "-")
        say(f"  {name:<{wn}}{pin:<{wp}}{at:<12}{newest:<{wv}}{how:<12}{mark}")
    # An idea is listed apart, and never as something this project is behind on.
    by_name = {(e.get("name") or e.get("source", "?")): e for e in watched}
    behind, to_read = [], []
    for name, _pin, _at, _newest, how, _real in rows:
        if not str(how).endswith("newer"):
            continue
        if _is_idea(by_name.get(name, {})):
            to_read.append(name)
        else:
            behind.append(name)
    blind = [name for name, _, _, _, how, _ in rows if how in ("unknown", "unreachable")]
    moved = [name for name, _, _, _, _, real in rows if real is False]
    say()
    if blind:
        say(f"UNKNOWN: {', '.join(blind)} — the source gave no answer about the pin. A watch that cannot")
        say("read its source is not a watch; fix the source or stop watching it.")
        for name in blind:
            if name in whynot:
                say(f"  {name}: {whynot[name]}")
    if moved:
        say(f"MOVED: {', '.join(moved)} — the file no longer holds that version. Fix the pin in {LIST}.")
    if behind:
        say(f"Newer: {', '.join(behind)}. Read one: just upstream {behind[0]}")
        say("Then decide. This command never upgrades anything.")
    elif blind and len(blind) == len(rows):
        say(f"No source gave an answer: {', '.join(blind)}. This report says nothing about")
        say("what is current; the reasons are above.")
    elif blind:
        say(f"Everything readable is current. No answer for: {', '.join(blind)}.")
    else:
        say("Everything watched is current.")
    if to_read:
        say(f"To read: {', '.join(to_read)}. An idea is not an upgrade. Read one: just upstream {to_read[0]}")
    if stale:
        say("Last result, kept because this run could not check:")
        for name, reason, record in stale:
            say(f"  {name}: {age_phrase(record)} ({reason}).")

    write_project_cache(rows, behind, moved)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(130)
