#!/usr/bin/env python3
"""Keep a cargo build folder under a cap, the oldest pieces first (spec 027).

    buildtrim.py <folder> <cap> [--now | --wait]

The cap is git's `ai-backbone.build-cap` as written: a number of GB ("60",
"30 GB", "1.5"), or off ("off", "0"); anything else is said, and 60 is used.

A Rust project's build folder grows without end: every change of a dependency,
a feature or a compiler leaves the old compiled units where they were, and on
one Mac several workspaces passed 200 GB each and left the disk 2.7 GB free.
Trimming by age alone did not keep up there (about 130 GB of output in one
day); a cap of 60 GB per project did. Over the cap, this removes the pieces
written longest ago until the folder is at 75% of it.

A piece is one compiled unit: what deps/, build/, .fingerprint/ and examples/
hold under one 16-digit hash, removed together, or one folder of incremental/.
cargo rebuilds a piece that is gone the next time it needs it (measured on
cargo 1.98.1: with a library's .rlib, its fingerprint or its build/ folders
deleted, the next build rebuilt them and ran).

Nothing at all while cargo, rustc or rustdoc runs on this machine: cargo lets
go of its locks when compiling ends, and a `cargo test` then runs the test
programs in deps/ for as long as they take (in review, a piece removed then
failed a running test). So --wait, the run a build starts in the background,
waits for a moment with none, an hour at most; --now says so and stops; and
both look again before each few seconds of removing, and stop when a build
has started. While removing a profile's pieces it holds that profile's cargo
locks, so a build that starts meanwhile waits for it rather than finding a
piece half gone, and each piece's age is read again under them.

Never removed besides: a piece written in the last 6 hours; the top-level
files of a profile, the programs a person runs; anything else that is no
piece; and every piece of a profile whose cargo lock is held. Under 15% free
disk the cap is halved. Only a folder cargo made is touched: CACHEDIR.TAG and
.rustc_info.json at its root. Where cargo's locks cannot be read (Windows,
where cargo locks another way, not measured), nothing is removed.

Each run writes one line to ai-backbone-trim.log in the folder, and with --now
prints it too; a run that finished touches ai-backbone-trim.done, by whose age
the recipes start one at most once an hour. One run at a time, by a lock of its
own. It never fails a build: what goes wrong is a line in the log.
"""

import datetime
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
HOLD = 5.0
COMPILERS = {"cargo", "rustc", "rustdoc"}
GB = 1024 ** 3
LOG = "ai-backbone-trim.log"
DONE = "ai-backbone-trim.done"
RUNNING = "ai-backbone-trim.lock"


def building():
    """Whether cargo, rustc or rustdoc runs on this machine; None when the
    process list cannot be read, which is no answer and so no go."""
    try:
        done = subprocess.run(["ps", "-A", "-o", "comm="], capture_output=True, text=True, timeout=20)
    except (OSError, subprocess.SubprocessError):
        return None
    names = [line.strip().rsplit("/", 1)[-1] for line in done.stdout.splitlines() if line.strip()]
    if done.returncode != 0 or not names:
        return None
    return any(n in COMPILERS for n in names)


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


def pieces(profile):
    """Each piece of a profile: (newest change, size, its paths)."""
    groups = {}
    for sub in PIECES:
        folder = profile / sub
        if not folder.is_dir():
            continue
        for entry in os.scandir(folder):
            found = HASH.search(entry.name)
            if found:
                groups.setdefault(found.group(1), []).append(Path(entry.path))
    inc = profile / "incremental"
    if inc.is_dir():
        for entry in os.scandir(inc):
            if entry.is_dir(follow_symlinks=False):
                groups["incremental/" + entry.name] = [Path(entry.path)]
    out = []
    for paths in groups.values():
        size, newest = 0, 0.0
        for p in paths:
            s, n = usage(p)
            size += s
            newest = max(newest, n)
        out.append((newest, size, paths))
    return out


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
    candidates = sorted((newest, size, paths, profile) for profile in profiles(root)
                        for newest, size, paths in pieces(profile) if now - newest > YOUNG)
    held, busy, removed, stopped = {}, set(), 0, False
    try:
        for newest, size, paths, profile in candidates:
            if total <= target:
                break
            if profile in busy:
                continue
            fds, since = held.get(profile, (None, 0.0))
            if fds is None or time.monotonic() - since > HOLD:
                release(fds)
                held.pop(profile, None)
                if fds is not None:
                    time.sleep(0.2)  # a build that waited gets its turn
                if building() is not False:
                    stopped = True
                    break
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
            total -= size
            removed += 1
    finally:
        for fds, _ in held.values():
            release(fds)
    line = f"{gb(before)} over the cap of {gb(cap)}{note}: removed {gb(before - total)} in {removed} pieces, {gb(total)} left"
    if busy:
        line += f"; a build was running in {', '.join(str(p.relative_to(root)) for p in sorted(busy))}, left alone"
    if stopped:
        line += "; stopped: a build started, so the rest waits for the next run"
    elif total > target and not busy:
        line += "; what is left is younger than 6 hours, or no piece (the programs themselves)"
    return line, not stopped


def main():
    flags = [a for a in sys.argv[1:] if a in ("--now", "--wait")]
    args = [a for a in sys.argv[1:] if a not in flags]
    now = "--now" in flags
    if len(args) != 2:
        print(__doc__.split("\n\n")[1])
        return 2
    root = Path(args[0])

    def say(line, done=False):
        line = f"{datetime.datetime.now():%Y-%m-%d %H:%M}  {line}"
        if now:
            print(line)
        log = root / LOG
        try:
            kept = log.read_text(errors="ignore").splitlines()[-199:] if log.is_file() else []
            log.write_text("\n".join(kept + [line]) + "\n")
            if done:
                (root / DONE).touch()
        except OSError:
            pass

    cap = parse_cap(args[1])
    if cap == 0:
        if now:
            print("Trimming is off here (git config ai-backbone.build-cap off): nothing removed.")
        return 0
    if not root.is_dir():
        if now:
            print(f"No build output yet at {args[0]}: nothing to trim.")
        return 0
    if not (root / "CACHEDIR.TAG").is_file() or not (root / ".rustc_info.json").is_file():
        if now:
            print(f"{args[0]} is not a folder cargo made (no CACHEDIR.TAG and .rustc_info.json): left alone.")
        return 0
    if fcntl is None:
        say("cargo's locks cannot be read on this system: nothing removed", done=True)
        return 0
    # One run at a time: a second one, started by another build, leaves.
    try:
        mine = os.open(root / RUNNING, os.O_RDWR | os.O_CREAT, 0o644)
        fcntl.flock(mine, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        if now:
            print("Another trim of this folder is running: nothing more to do.")
        return 0
    note = ""
    if cap is None:
        note, cap = f"build-cap {args[1]!r} is not a number of GB, so 60 is used; ", 60.0
    waited, state = 0, building()
    while "--wait" in flags and state and waited < 3600:
        time.sleep(30)
        waited += 30
        state = building()
    if state is None:
        say(note + "the process list cannot be read, so whether a build runs is unknown: nothing removed", done=True)
        return 0
    if state:
        say(note + ("a build is running on this machine: nothing removed; run it again when it ends" if now
                    else "a build ran the whole hour: the next build tries again"))
        return 0
    try:
        line, finished = trim(root, cap * GB)
    except Exception as err:  # noqa: BLE001 - a build is never failed by this
        line, finished = f"stopped: {type(err).__name__}: {err}", False
    say(note + line, done=finished)
    return 0


if __name__ == "__main__":
    sys.exit(main())
