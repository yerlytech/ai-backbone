#!/usr/bin/env python3
"""What the things this project is built on have released since we pinned them.

Reads `docs/upstream.toml`, asks each source what it has published, and prints
what is newer than the pin. With a name, prints the release notes themselves,
because the version number is the least useful half of the answer: what matters
is what changed and what it costs to follow.

It also says when each pinned version came out and where that version can be
read on this machine, because an agent's training ends on a day and a version
released after it is one the agent has never seen. `--recent` prints that from
the cache alone, without the network, for every session. `--advisories` reads
a Cargo.lock against the RustSec advisories, and `--crate-sources` says when
a row reads from GitHub what Cargo.lock locks as a crate (spec 029); what a
project has looked at and ships anyway is in docs/advisories.toml, and
`--advisories gate` is a ship's yes or no (spec 030).

Nothing here upgrades anything. It reports.
"""

import collections
import datetime
import glob
import http.client
import io
import json
import os
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import time
import urllib.error
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


def say(line=""):
    print(line, flush=True)


def fetch_json(url, headers=None):
    request = urllib.request.Request(url, headers=headers or {"User-Agent": "ai-backbone"})
    with urllib.request.urlopen(request, timeout=10) as response:
        return json.load(response)


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
            check=False, capture_output=True, text=True, timeout=30,
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
            check=False, capture_output=True, text=True, timeout=30,
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
                check=False, capture_output=True, text=True, timeout=30,
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


def github_one(repo, path):
    """One object from the GitHub API, or None when there is none. Through gh
    when it is installed, since it carries the login; plain HTTPS otherwise."""
    try:
        if shutil_which("gh"):
            done = subprocess.run(["gh", "api", f"repos/{repo}/{path}"],
                                  check=False, capture_output=True, text=True, timeout=30)
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
    data = fetch_json(f"https://registry.npmjs.org/{name}")
    times = data.get("time", {})
    versions = [v for v in data.get("versions", {})]
    versions.sort(key=lambda v: times.get(v, ""), reverse=True)
    return [
        {"version": v, "at": (times.get(v) or "")[:10], "title": v, "notes": "",
         "url": f"https://www.npmjs.com/package/{name}/v/{v}",
         "prerelease": "-" in v.split("+", 1)[0]}
        for v in versions
    ]


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


def by_commit(entry):
    """Whether a row's versions are commits (hf:), so its pin is a commit id
    and is matched by its first characters, not compared as a number."""
    return entry.get("source", "").partition(":")[0] == "hf"


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


def released_at(entry, releases, known=""):
    """The day the pinned version itself came out — not the newest one, the one
    this project runs on. From what the source listed when it is there; a tag
    may carry a v the pin does not, or the other way round. A date learned in an
    earlier week (`known`) is kept, since it does not change. Only then does a
    GitHub pin older than the fifty fetched cost one more call per tag form,
    and a project that tags without releasing answers with the commit's date."""
    pin = str(entry.get("pin", "")).strip()
    for release in releases:
        if release["version"].lstrip("vV") == pin.lstrip("vV") and release["at"]:
            return release["at"]
    kind, _, repo = entry.get("source", "").partition(":")
    if known or kind != "github" or not pin or OFFLINE:
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
    elif bare:
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
    # A model is no program: a binary that shares its name says nothing about it.
    exe = None if kind == "hf" else shutil_which("flutter" if kind == "flutter" else name)
    repo = {"github": rest, "flutter": "flutter/flutter"}.get(kind)
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
        done = subprocess.run(command, check=False, capture_output=True, text=True, timeout=5,
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
           "pypi": from_pypi, "flutter": from_flutter, "hf": from_hf}


def look(entry):
    """A source this script cannot read is said first, online or not: a typo in
    the list is the reader's to fix, and offline mode must not hide it."""
    source = entry.get("source", "")
    kind, _, rest = source.partition(":")
    if kind not in SOURCES or not rest:
        raise ValueError(f"unknown source `{source}` — use github:owner/repo, crates:name, npm:name,"
                         " pub:name, pypi:name, flutter:stable or hf:owner/name")
    if OFFLINE:
        raise Unreachable("offline: AI_BACKBONE_OFFLINE is set")
    if kind == "hf":
        return from_hf(rest, entry.get("pin", ""))
    return SOURCES[kind](rest)


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
    """Every session, without the network, from what the weekly run cached: what
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
        say("Released in the last 12 months: not known yet. The weekly check fills it in"
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
            + ". The weekly check fills it in when the source can be reached.")
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
    with urllib.request.urlopen(request, timeout=15) as response:
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


def main():
    # Before the list is read, and so before tomllib: these lines need neither.
    if len(sys.argv) > 1 and sys.argv[1] == "--recent":
        return recent()
    if len(sys.argv) > 1 and sys.argv[1] == "--crate-sources":
        return crate_sources(sys.argv[2:])
    if len(sys.argv) > 2 and sys.argv[1] == "--advisories" and sys.argv[2] == "gate":
        return advisories_gate(sys.argv[3:])
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

    only = sys.argv[1] if len(sys.argv) > 1 else ""
    found = {}
    rows = []
    whynot = {}
    unlisted = set()
    before = cached_dates()
    silent = 0
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
        held = before.get(name)
        known = held.get("at", "") if isinstance(held, dict) and held.get("pin") == entry.get("pin", "?") else ""
        try:
            releases = tagged(entry, look(entry))
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
        at = released_at(entry, releases, known) or "?"
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

    if only:
        # Looked up in the list, not in what answered: a name whose source was
        # silent used to be told it "is not in" the list it was sitting in.
        entry = next((e for e in watched if (e.get("name") or e.get("source", "?")) == only), None)
        if entry is None:
            say(f"`{only}` is not in {LIST}.")
            return 1
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
    behind = [name for name, _, _, _, how, _ in rows if how.endswith("newer")]
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

    if CACHE.parent.is_dir():
        released = {name: {"pin": pin, "at": "" if at == "?" else at} for name, pin, at, *_ in rows}
        CACHE.write_bytes(json.dumps({"behind": behind, "moved": moved, "released": released}, indent=1).encode("utf-8"))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(130)
