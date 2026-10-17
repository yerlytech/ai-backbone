#!/usr/bin/env python3
"""Keep a cargo build folder under a cap, the pieces no build has used for
longest first (spec 027; the order since spec 029).

    buildtrim.py <folder> <cap> [--now | --wait]
    buildtrim.py --machine [--free <percent>] <folder> <another folder>...

The cap is git's `ai-backbone.build-cap` as written: a number of GB ("60",
"30 GB", "1.5"), or off ("off", "0"); anything else is said, and 60 is used.

A Rust project's build folder grows without end: every change of a dependency,
a feature or a compiler leaves the old compiled units where they were, and on
one Mac several workspaces passed 200 GB each and left the disk 2.7 GB free.
Trimming by age alone did not keep up there (about 130 GB of output in one
day); a cap of 60 GB per project did. Over the cap, this removes the pieces
used longest ago until the folder is at 75% of it.

Used, and not written: a dependency is compiled once and never written again,
so the pieces a project still builds against were the oldest, and went first,
and every crate above a removed one was compiled again (spec 029). What a piece
was built against is in cargo's own records: each unit's file in .fingerprint/
holds its fingerprint, and the .json beside it the fingerprints of the units it
was built against (measured on cargo 1.99.0; the file writes the number's bytes
lowest first, the .json writes the number). A unit nothing was built against
is a root, the program or test a build ends in, and its files are written each
time a build makes it; a piece was last used when the newest root that reaches
it was. A piece reached only from a root a feature change or an update left
behind goes first. A piece a root of the last day before the newest one
reaches is never removed, since the next build would compile it again, and
every crate above it; unless a newer root of the same crate, kind and build
(cargo's records say each) has taken that root's place, as a feature change
or an update does: a folder that took in 150 GB in one day was all of that
day. Two variants both in use, two branches or worktrees on one folder, look
the same as one replaced, since a build with nothing to do writes nothing: the
older one's own pieces may go, in the order of their last use. One graph for the whole folder: a build for another target reaches the
build scripts and macros it compiled for this machine in debug/, and a profile
nobody builds any more is not kept for ever. Measured on cargo 1.99.0, the same toolchain
throughout and no compiler cache: a folder of 236 MB, 47 MB of it left behind
by a feature change, trimmed with a cap just under its size. Written-first
removed 64 MB in 42 pieces and the next build compiled 43 crates again, 8.1 s
of a 9.3 s build from nothing; this order removed the 11 pieces left behind,
and the next build compiled nothing. Where the records cannot be read, a piece
was used when it was written. A file's read time cannot say it: macOS writes
one only at the first read after a write (measured on APFS), so a dependency
compiled weeks ago looks as unread as one a build has left behind.

A piece is one compiled unit: what deps/, build/, .fingerprint/ and examples/
hold under one 16-digit hash, removed together, or one folder of incremental/.
cargo rebuilds a piece that is gone the next time it needs it (measured on
cargo 1.98.1: with a library's .rlib, its fingerprint or its build/ folders
deleted, the next build rebuilt them and ran).

Nothing in a profile a running program uses: cargo lets go of its locks when
compiling ends, and a `cargo test` then runs the test programs in deps/ for as
long as they take (in review, a piece removed then failed a running test). A
program uses a profile when its command line names a folder of pieces there:
a rustc writing into deps/, a test program run from it, a rustdoc linking
against it, a build script (`ps -o args`, measured on macOS: cargo passes them
whole paths). A build of another folder holds nothing back; until 3.38.1 any
compiler on the machine did, and with six projects building there was always
one, so the trim never ran. --wait, the run a build starts in the
background, waits until nothing uses the folder, an hour at most; --now does
not wait; and both look again before each few seconds of removing, and leave
a profile alone once something uses it. While removing a profile's pieces it
holds that profile's cargo locks, so a build that starts meanwhile waits for
it rather than finding a piece half gone, and each piece's age is read again
under them.

Never removed besides: a piece used in the last 6 hours; the top-level
files of a profile, the programs a person runs; anything else that is no
piece; and every piece of a profile whose cargo lock is held. Under 15% free
disk the cap is halved. Only a folder cargo made is touched: CACHEDIR.TAG and
.rustc_info.json at its root. Where cargo's locks cannot be read (Windows,
where cargo locks another way, not measured), nothing is removed.

One disk, many projects (spec 032): each folder's cap is its own, and nine
folders each under a cap of 150 GB filled a 926 GB disk at 60 GB an hour.
--machine is the run a build starts after its own folder's: with less than
15% of the disk free, it goes through the other projects' cargo folders on the
same disk, the one built longest ago first, and takes from each one that no
build has written in 7 days what its next build would make again, oldest
used first, until 20% is free. The working set of an idle project too: the
price is one full build when somebody comes back to it, and a full disk stops
every project (the owner's yes, 2026-10-17). Never a folder something uses
now, whole or in part; each folder trimmed gets its line in its own log.

Each run writes one line to ai-backbone-trim.log in the folder, and with --now
prints it too; a run that finished touches ai-backbone-trim.done, by whose age
the recipes start one at most once an hour. One run at a time, by a lock of its
own. It never fails a build: what goes wrong is a line in the log.
"""

import datetime
import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

try:
    import fcntl
except ImportError:
    # Windows: cargo locks there with LockFileEx, which nobody has measured
    # against Python's locks, so no profile counts as free and nothing goes.
    fcntl = None

HASH = re.compile(r"-([0-9a-f]{16})(?=$|[.\-_])")
PIECES = ("deps", "build", ".fingerprint", "examples")
# Measured on cargo 1.98.1: a build holds .cargo-build-lock and
# .cargo-artifact-lock; .cargo-lock is the name older versions used.
LOCKS = (".cargo-lock", ".cargo-build-lock", ".cargo-artifact-lock")
YOUNG = 6 * 3600
IDLE = 7 * 86400
FULL, ENOUGH = 0.15, 0.20
IN_USE = 24 * 3600
HOLD = 5.0
GB = 1024 ** 3
LOG = "ai-backbone-trim.log"
DONE = "ai-backbone-trim.done"
RUNNING = "ai-backbone-trim.lock"


def users(root):
    """The profiles of root whose pieces a running program names in its
    command line: a rustc writing into deps/, a test program run from it, a
    rustdoc linking against it, a build script. None when the process list
    cannot be read, which is no answer and so no go. A program run from the
    top of a profile, a server left running, names none: nothing there is
    ever removed. A build of another folder is not this one's business: with
    six projects building, one machine always had a compiler running, the
    trim never ran, and a folder grew 24 GB an hour (spec 029, 3.38.1)."""
    lines = None
    for cmd in (["ps", "-A", "-ww", "-o", "args="], ["ps", "-A", "-o", "args="]):
        try:
            done = subprocess.run(cmd, capture_output=True, text=True, timeout=20)
        except (OSError, subprocess.SubprocessError):
            continue
        if done.returncode == 0 and done.stdout.strip():
            # Another trim names the folder too; its own lock keeps it apart.
            lines = [line for line in done.stdout.splitlines() if "buildtrim.py" not in line]
            break
    if lines is None:
        return None
    found = set()
    for profile in profiles(root):
        forms = {str(profile), os.path.abspath(profile), os.path.realpath(profile)}
        needles = [f"{f}/{sub}" for f in forms for sub in PIECES + ("incremental",)]
        if any(n in line for line in lines for n in needles):
            found.add(profile)
    return found


def parse_cap(text):
    """GB as a number, 0 for off, None when it says neither."""
    t = str(text).strip().lower()
    if t in ("off", "false", "no", "none"):
        return 0.0
    t = re.sub(r"\s*gb?$", "", t)
    try:
        cap = float(t)
    except ValueError:
        return None
    return cap if cap >= 0 else None


def gb(n):
    return f"{n / GB:.1f} GB" if n >= GB else f"{n / 1048576:.0f} MB"


def usage(path):
    """Bytes on disk and the newest change, of a file or a whole folder. Links
    are not followed: a link inside a build folder points somewhere else."""
    size, newest = 0, 0.0
    stack = [str(path)]
    while stack:
        p = stack.pop()
        try:
            st = os.lstat(p)
        except OSError:
            continue
        size += st.st_blocks * 512 if hasattr(st, "st_blocks") else st.st_size
        newest = max(newest, st.st_mtime)
        if os.path.isdir(p) and not os.path.islink(p):
            try:
                stack.extend(e.path for e in os.scandir(p))
            except OSError:
                pass
    return size, newest


def profiles(root):
    """target/debug, target/release, target/<triple>/<profile>: every folder
    that holds deps/ or .fingerprint/, one or two levels down."""
    def is_profile(d):
        return (d / "deps").is_dir() or (d / ".fingerprint").is_dir()
    out = []
    for a in sorted(root.iterdir()):
        if not a.is_dir() or a.is_symlink():
            continue
        if is_profile(a):
            out.append(a)
            continue
        for b in sorted(a.iterdir()):
            if b.is_dir() and not b.is_symlink() and is_profile(b):
                out.append(b)
    return out


def ties(profiles):
    """For each piece cargo has a record of, (profile, hash), the pieces it was
    built against, and what it is: its crate, its kind, and the target, profile,
    features, platform, config and flags it was built for, so that the same
    program built again under a new hash is known as the same (a test, a check
    and a build of it differ in kind or profile). In every profile at once: a
    build for another target reaches the build scripts and macros it compiled
    for this machine, in debug/."""
    owner, wants, ident = {}, {}, {}
    for profile in profiles:
        folder = profile / ".fingerprint"
        if not folder.is_dir():
            continue
        for entry in os.scandir(folder):
            found = HASH.search(entry.name)
            if not found or not entry.is_dir(follow_symlinks=False):
                continue
            piece = (profile, found.group(1))
            for f in os.scandir(entry.path):
                if not f.name.endswith(".json"):
                    continue
                try:
                    value = Path(f.path[:-5]).read_text().strip()
                    data = json.loads(Path(f.path).read_text())
                    values = {int(d[3]).to_bytes(8, "little").hex() for d in data["deps"]}
                    ident[piece] = (profile, entry.name[:found.start()], f.name[:-5]) + tuple(
                        str(data.get(k)) for k in ("target", "profile", "features", "compile_kind", "config", "rustflags"))
                except (OSError, ValueError, TypeError, KeyError, IndexError, OverflowError, AttributeError):
                    continue
                owner.setdefault(value, set()).add(piece)
                wants.setdefault(piece, set()).update(values)
    # One value can be two pieces': a build script run is fingerprinted without
    # its profile, so a crate built as a build dependency and as a dependency
    # has two runs with one value, and a folder for another target, or another
    # cargo folder inside this one, repeats them (measured in review). Each is
    # reached: in the same profile when one is there, else wherever it is.
    def reached(piece, values):
        out = set()
        for v in values:
            here = {o for o in owner.get(v, ()) if o[0] == piece[0]}
            out |= here or owner.get(v, set())
        return out - {piece}
    return {piece: reached(piece, values) for piece, values in wants.items()}, ident


def last_use(written, against, ident):
    """When each piece was last used, when the newest root was written, and
    which pieces stay. A piece was used when the newest root that reaches it was
    written; one with no record, when it was written. What stays: what a root
    of the last day before the newest one reaches, unless a newer root of the
    same crate, kind and build has taken that root's place; and a piece with no
    record written in that day."""
    below = set().union(*against.values()) if against else set()
    roots = sorted(((written[p], p) for p in against if p not in below and p in written), reverse=True)
    latest = roots[0][0] if roots else None
    use, stays, seen = {}, set(), set()
    for when, root in roots:
        current = ident.get(root) not in seen and when > latest - IN_USE
        seen.add(ident.get(root))
        stack = [root]
        while stack:
            p = stack.pop()
            if p in (stays if current else use):
                continue
            use.setdefault(p, when)
            if current:
                stays.add(p)
            stack.extend(against.get(p, ()))
    if latest is not None:
        stays.update(p for p, w in written.items() if p not in against and w > latest - IN_USE)
    return {p: max(w, use.get(p, 0.0)) for p, w in written.items()}, latest, stays


def pieces(profiles):
    """Each piece of these profiles: (last use, size, its paths, its profile,
    whether it stays), and when the newest root was written, or None where
    cargo's records say nothing."""
    groups = {}
    for profile in profiles:
        for sub in PIECES:
            folder = profile / sub
            if not folder.is_dir():
                continue
            for entry in os.scandir(folder):
                found = HASH.search(entry.name)
                if found:
                    groups.setdefault((profile, found.group(1)), []).append(Path(entry.path))
        inc = profile / "incremental"
        if inc.is_dir():
            for entry in os.scandir(inc):
                if entry.is_dir(follow_symlinks=False):
                    groups[(profile, "incremental/" + entry.name)] = [Path(entry.path)]
    sizes, written = {}, {}
    for key, paths in groups.items():
        size, newest = 0, 0.0
        for p in paths:
            s, n = usage(p)
            size += s
            newest = max(newest, n)
        sizes[key], written[key] = size, newest
    used, latest, stays = last_use(written, *ties(profiles))
    return [(used[key], sizes[key], paths, key[0], key in stays) for key, paths in groups.items()], latest


def lock(profile):
    """The profile's cargo locks, held, or None when a build holds one."""
    if fcntl is None:
        return None
    held = []
    for name in LOCKS:
        path = profile / name
        if not path.is_file():
            continue
        try:
            fd = os.open(path, os.O_RDWR)
        except OSError:
            release(held)
            return None
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError:
            os.close(fd)
            release(held)
            return None
        held.append(fd)
    return held


def release(held):
    for fd in held or ():
        os.close(fd)


def remove(paths):
    for p in paths:
        try:
            if p.is_dir() and not p.is_symlink():
                shutil.rmtree(p, ignore_errors=True)
            else:
                p.unlink()
        except FileNotFoundError:
            pass


def trim(root, cap):
    """What was done, as one line, and whether the run finished."""
    free = shutil.disk_usage(root)
    note = ""
    if free.total and free.free / free.total < 0.15:
        cap /= 2
        note = f" (halved: {free.free * 100 // free.total}% of the disk is free)"
    total, _ = usage(root)
    if total <= cap:
        return f"{gb(total)}, under the cap of {gb(cap)}{note}: nothing removed", True
    target, before, now = cap * 0.75, total, time.time()
    found, latest = pieces(profiles(root))
    candidates = sorted(piece[:4] for piece in found if now - piece[0] > YOUNG and not piece[4])
    kept = sum(piece[1] for piece in found if piece[4])
    freed, removed, busy, stopped = sweep(root, candidates, lambda freed: before - freed <= target)
    total = before - freed
    line = f"{gb(before)} over the cap of {gb(cap)}{note}: removed {gb(before - total)} in {removed} pieces, {gb(total)} left"
    if latest is None and removed:
        line += "; cargo's records could not be read, so the pieces written longest ago went first"
    if busy:
        line += f"; {', '.join(str(p.relative_to(root)) for p in sorted(busy))} in use by a build or its programs, left alone"
    if stopped:
        line += "; stopped: the process list could not be read, so the rest waits for the next run"
    elif total > target and not busy:
        line += ("; what is left was used in the last 6 hours, or is no piece (the programs themselves), or is"
                 " what the newest builds of the last day reach, which the next build would compile again")
        if kept > target:
            line += (f": {gb(kept)} of it, more than 75% of the cap, so the cap is below what this"
                     " project's builds need (git config ai-backbone.build-cap <GB> raises it)")
    return line, not stopped and not busy


def sweep(root, candidates, enough):
    """Remove the candidates, (last use, size, paths, profile), in order until
    enough(bytes removed) says so, each profile under its cargo locks and none
    a running program uses. The bytes removed, the pieces, the profiles in use,
    and whether it stopped because the process list could not be read."""
    held, busy, freed, removed, stopped = {}, set(), 0, 0, False
    try:
        for newest, size, paths, profile in candidates:
            if enough(freed):
                break
            if profile in busy:
                continue
            fds, since = held.get(profile, (None, 0.0))
            if fds is None or time.monotonic() - since > HOLD:
                release(fds)
                held.pop(profile, None)
                if fds is not None:
                    time.sleep(0.2)  # a build that waited gets its turn
                using = users(root)
                if using is None:
                    stopped = True
                    break
                if profile in using:
                    busy.add(profile)
                    continue
                fds = lock(profile)
                if fds is None:
                    busy.add(profile)
                    continue
                held[profile] = (fds, time.monotonic())
            # Read again under the lock: a unit rebuilt since keeps its hash.
            size, newest = 0, 0.0
            for p in paths:
                s, n = usage(p)
                size, newest = size + s, max(newest, n)
            if time.time() - newest <= YOUNG:
                continue
            remove(paths)
            freed += size
            removed += 1
    finally:
        for fds, _ in held.values():
            release(fds)
    return freed, removed, busy, stopped


def cargo_made(root):
    return (root / "CACHEDIR.TAG").is_file() and (root / ".rustc_info.json").is_file()


def last_built(root):
    """When a build last wrote in the folder: the newest of its units' records
    in .fingerprint/, which cargo writes for each unit it compiles; the
    folder's own date where there are none. One look per unit, not per file."""
    newest = 0.0
    for profile in profiles(root):
        folder = profile / ".fingerprint"
        try:
            entries = list(os.scandir(folder))
        except OSError:
            continue
        for e in entries:
            try:
                newest = max(newest, e.stat(follow_symlinks=False).st_mtime)
            except OSError:
                pass
    if not newest:
        try:
            newest = root.stat().st_mtime
        except OSError:
            pass
    return newest


def log(root, line, done=False):
    line = f"{datetime.datetime.now():%Y-%m-%d %H:%M}  {line}"
    path = root / LOG
    try:
        kept = path.read_text(errors="ignore").splitlines()[-199:] if path.is_file() else []
        path.write_text("\n".join(kept + [line]) + "\n")
        if done:
            (root / DONE).touch()
    except OSError:
        pass
    return line


def machine(own, folders, share=None):
    """With less than 15% of the disk free, the other projects' cargo folders
    on that disk that no build has written in 7 days, the one built longest
    ago first, lose what a build makes again, oldest used first, until 20% is
    free. What was done, one line a folder, each in that folder's log too.
    share: the free percent the caller measured (df), else this one's own."""
    if fcntl is None:
        return []
    disk = shutil.disk_usage(own)
    if not disk.total:
        return []
    free = disk.total * share / 100 if share is not None else disk.free
    if free / disk.total >= FULL:
        return []
    need = disk.total * ENOUGH - free
    pct = int(free * 100 // disk.total)
    try:
        dev = os.stat(own).st_dev
    except OSError:
        return []
    now, seen, idle = time.time(), {os.path.realpath(own)}, []
    for f in folders:
        root = Path(f)
        real = os.path.realpath(root)
        if real in seen or not root.is_dir() or not cargo_made(root):
            continue
        seen.add(real)
        try:
            if os.stat(root).st_dev != dev:
                continue
        except OSError:
            continue
        when = last_built(root)
        if now - when > IDLE:
            idle.append((when, root))
    lines = []
    for when, root in sorted(idle):
        if need <= 0:
            break
        days = int((now - when) // 86400)
        try:
            mine = os.open(root / RUNNING, os.O_RDWR | os.O_CREAT, 0o644)
            fcntl.flock(mine, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError:
            continue
        try:
            using = users(root)
            if using is None:
                break
            if using:
                lines.append(log(root, f"{pct}% of the disk is free; this folder, idle for {days} days, is in use now: left alone"))
                continue
            found, _ = pieces(profiles(root))
            candidates = sorted(piece[:4] for piece in found if now - piece[0] > YOUNG)
            freed, removed, busy, stopped = sweep(root, candidates, lambda freed: freed >= need)
            need -= freed
            line = (f"{pct}% of the disk was free, under 15%, and this folder was last built {days} days ago:"
                    f" removed {gb(freed)} in {removed} pieces, the oldest used first, toward 20% free;"
                    " its next build compiles them again")
            if busy:
                line += f"; {', '.join(str(p.relative_to(root)) for p in sorted(busy))} in use, left alone"
            if stopped:
                line += "; stopped: the process list could not be read"
            lines.append(log(root, line))
            if stopped:
                break
        finally:
            os.close(mine)
    return lines


def main():
    if sys.argv[1:2] == ["--machine"]:
        rest, share = sys.argv[2:], None
        if rest[:1] == ["--free"] and len(rest) > 1:
            try:
                share = float(rest[1])
            except ValueError:
                pass
            rest = rest[2:]
        if not rest:
            print(__doc__.split("\n\n")[1])
            return 2
        try:
            for line in machine(Path(rest[0]), rest[1:], share):
                print(line)
        except Exception:  # noqa: BLE001 - a build is never failed by this
            pass
        return 0
    flags = [a for a in sys.argv[1:] if a in ("--now", "--wait")]
    args = [a for a in sys.argv[1:] if a not in flags]
    now = "--now" in flags
    if len(args) != 2:
        print(__doc__.split("\n\n")[1])
        return 2
    root = Path(args[0])

    def say(line, done=False):
        line = log(root, line, done)
        if now:
            print(line)

    cap = parse_cap(args[1])
    if cap == 0:
        if now:
            print("Trimming is off here (git config ai-backbone.build-cap off): nothing removed.")
        return 0
    if not root.is_dir():
        if now:
            print(f"No build output yet at {args[0]}: nothing to trim.")
        return 0
    if not cargo_made(root):
        if now:
            print(f"{args[0]} is not a folder cargo made (no CACHEDIR.TAG and .rustc_info.json): left alone.")
        return 0
    note = ""
    if cap is None:
        note, cap = f"build-cap {args[1]!r} is not a number of GB, so 60 is used; ", 60.0
    if fcntl is None:
        # Under the cap that is the whole answer; over it, nothing can go here.
        total, _ = usage(root)
        say(note + (f"{gb(total)}, under the cap of {gb(cap * GB)}: nothing removed" if total <= cap * GB
                    else f"{gb(total)} over the cap of {gb(cap * GB)}; cargo's locks cannot be read on this system: nothing removed"),
            done=True)
        return 0
    # One run at a time: a second one, started by another build, leaves.
    try:
        mine = os.open(root / RUNNING, os.O_RDWR | os.O_CREAT, 0o644)
        fcntl.flock(mine, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        if now:
            print("Another trim of this folder is running: nothing more to do.")
        return 0
    # The run a build starts waits for that build, and any other using this
    # folder, to end, an hour at most; then a profile still in use is left
    # alone and the rest is trimmed. --now does not wait.
    waited, state = 0, users(root)
    while "--wait" in flags and state and waited < 3600:
        time.sleep(30)
        waited += 30
        state = users(root)
    if state is None:
        say(note + "the process list cannot be read, so whether a build uses this folder is unknown: nothing removed", done=True)
        return 0
    try:
        line, finished = trim(root, cap * GB)
    except Exception as err:  # noqa: BLE001 - a build is never failed by this
        line, finished = f"stopped: {type(err).__name__}: {err}", False
    say(note + line, done=finished)
    return 0


if __name__ == "__main__":
    sys.exit(main())
