#!/usr/bin/env python3
"""What the things this project is built on have released since we pinned them.

Reads `docs/upstream.toml`, asks each source what it has published, and prints
what is newer than the pin. With a name, prints the release notes themselves,
because the version number is the least useful half of the answer: what matters
is what changed and what it costs to follow.

It also says when each pinned version came out and where that version can be
read on this machine, because an agent's training ends on a day and a version
released after it is one the agent has never seen. `--recent` prints that from
the cache alone, without the network, for every session.

Nothing here upgrades anything. It reports.
"""

import collections
import datetime
import glob
import http.client
import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path

# Python on Windows writes "\r\n" for every "\n", and the recipes compare what
# it says as text: "removed\r" is not "removed" (spec 020). LF on every machine;
# the encoding is PYTHONUTF8's, which core.just sets.
for _stream in (sys.stdout, sys.stderr):
    if hasattr(_stream, "reconfigure"):
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
    date a version by its paperwork — SurrealDB's 3.2.1 to 3.2.4 share one
    afternoon, two weeks after the last of them was on crates.io — so the
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
            capture_output=True, text=True, timeout=30,
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
        row["prerelease"] = bool(re.search(r"[-._](rc|alpha|beta|pre|dev|preview)(?![a-z])", row["version"], re.I))
    return rows


def from_github(repo):
    """Releases newest first, falling back to tags for a project that tags only
    — with gh or without it: without the fallback a tags-only project read as
    "nothing published" on a machine with no gh, and the report said to stop
    watching it. When the API refuses altogether, the tags are asked of git."""
    if shutil_which("gh"):
        done = subprocess.run(
            ["gh", "api", f"repos/{repo}/releases?per_page=50"],
            capture_output=True, text=True, timeout=30,
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
                capture_output=True, text=True, timeout=30,
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
                                  capture_output=True, text=True, timeout=30)
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


def shutil_which(name):
    from shutil import which
    return which(name)


# Where the version starts inside a tag: at the first number that begins a word,
# with or without a `v`. The 2 in `a2ui` does not begin one, the 0 in `rust-v0.155.1`
# and in `python/a2ui-core/v0.1.1` does. A date is tried first, so that the hyphens
# of 2026-07-28 are not read as the start of a suffix. An underscore joins numbers
# too, because PostgreSQL writes REL_17_2.
VERSION = re.compile(r"(?<![a-z0-9])(?<![0-9][._])v?(\d{4}-\d\d-\d\d(?!\d)|\d+(?:[._]\d+)*)")
# A version glued to its word, as in go1.24.0 and FFmpeg's n7.1: tried second, and only with a dot in it, so a2ui stays a word.
GLUED = re.compile(r"(?<![0-9._])(\d+(?:[._]\d+)+)")
DATED = re.compile(r"(?<![a-z0-9])v?\d{2,4}-\d\d-\d\d(?!\d)")


def shape(version):
    """A tag in two pieces: the label before the version, and the version as
    something that sorts. Three real repositories, read on 2026-09-19, are why
    there is a label at all. google/A2UI tags its sub-packages by path, and
    `python/a2ui-agent-sdk/v0.6.0` is not the next version of a pin of `v0.9`.
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
    tags = list(dict.fromkeys([pin, "v" + pin.lstrip("vV"), pin.lstrip("vV")]))
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
    if entry.get("pinned_in"):
        if pin_is_real(entry):
            out.append(("pinned in", entry["pinned_in"]))
        else:
            out.append(("listed in", f"{entry['pinned_in']}   (does not hold {pin or 'a pin'})"))
    folders = []
    if bare:
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
    exe = shutil_which("flutter" if kind == "flutter" else name)
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
            mine = re.search(rf"github\.com[:/]{re.escape(repo)}(\.git)?/?$", origin, re.I)
            return str(folder) if mine else ""
    return ""


def said(command):
    """The first line a command printed, or nothing. Five seconds and no
    keyboard: a binary that happens to be named like a watch must not be able
    to hold `just upstream <name>` for as long as it likes."""
    try:
        done = subprocess.run(command, capture_output=True, text=True, timeout=5,
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
    source tags it (rust-v0.155.0), is also held by a file that says 0.155.0."""
    where = entry.get("pinned_in")
    if not where:
        return None
    path = Path(where)
    pin = str(entry.get("pin", "")).strip()
    if not pin or not path.is_file():
        return False
    text = path.read_text(errors="ignore")
    label = shape(pin)[0]
    forms = {pin, pin[len(label):].lstrip("vV")} if label else {pin}
    return any(re.search(rf"(?<![0-9])(?<![0-9]\.){re.escape(form)}(?![0-9])", text) for form in forms if form)


SOURCES = {"github": from_github, "crates": from_crates, "npm": from_npm, "pub": from_pub,
           "flutter": from_flutter}


def look(entry):
    """A source this script cannot read is said first, online or not: a typo in
    the list is the reader's to fix, and offline mode must not hide it."""
    source = entry.get("source", "")
    kind, _, rest = source.partition(":")
    if kind not in SOURCES or not rest:
        raise ValueError(f"unknown source `{source}` — use github:owner/repo, crates:name, npm:name,"
                         " pub:name or flutter:stable")
    if OFFLINE:
        raise Unreachable("offline: AI_BACKBONE_OFFLINE is set")
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
    say("Built on: " + " · ".join(f"{name} {pin}" for name, pin in pins) + f" ({LIST})")
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


def main():
    # Before the list is read, and so before tomllib: these lines need neither.
    if len(sys.argv) > 1 and sys.argv[1] == "--recent":
        return recent()
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
            releases = look(entry)
        except (OSError, ValueError, http.client.HTTPException,
                subprocess.TimeoutExpired, Unreachable) as err:
            # The reason goes to `whynot`, not into the table: it is a sentence,
            # the column is twelve wide, and a row that overflows takes the
            # column the summary below reads from with it. What a proxy answers
            # can be a page long; what this script says is one line. The pin is
            # checked all the same: that needs the file, not the network.
            whynot[name] = " ".join(str(err).split())[:120]
            # A refusal (404, 403) is an answer: the network works. Only silence counts.
            if isinstance(err, subprocess.TimeoutExpired) or (
                    isinstance(err, OSError) and not isinstance(err, urllib.error.HTTPError)):
                silent += 1
            rows.append((name, entry.get("pin", "?"), known or "?", "?", "unreachable", pin_is_real(entry)))
            continue
        silent = 0
        at = released_at(entry, releases, known) or "?"
        if not releases:
            rows.append((name, entry.get("pin", "?"), at, "nothing published", "unknown", pin_is_real(entry)))
            continue
        ahead = newer_than(entry.get("pin", "0"), releases, entry.get("prereleases", False))
        # Nothing newer is "current" only when the source lists the pin itself.
        silence = "" if ahead else unanswered(entry.get("pin", "0"), releases)
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
            say(f"     {what:<10} {path}")
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
        CACHE.write_text(json.dumps({"behind": behind, "moved": moved, "released": released}, indent=1))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(130)
