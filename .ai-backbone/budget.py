#!/usr/bin/env python3
"""What this machine can know about the week's limit, and how many subagents a
session may start before it asks (spec 014).

A running agent cannot ask Claude how much of the weekly limit is left: /usage
is for a person. But Claude Code keeps the last answer it got in `~/.claude.json`
under `cachedUsageUtilization` (measured on 2.1.273: a percentage for the
seven-day and the five-hour window, when each resets, and when it was read), and
every transcript under `~/.claude/projects/` carries, on each assistant message,
the usage the API answered with: input, cache creation, cache read and output
tokens, the model, and a timestamp. The meter is the truth and counts what this
machine never sees (the cloud routine, claude.ai); the transcripts say what this
machine spent since it was read. Local tokens alone would mislead: one week's
100% was 5.0 billion raw tokens and the next week's 46% was 1.5 billion. So the
meter anchors and the transcripts only fill the minutes since.

    budget.py --line tr|en      one line for the start of a session; never fails
    budget.py                   the week and the day in full
    budget.py --json            the same as one JSON object
    budget.py hook add|remove|check [.claude/settings.json]
                                the subagent-cap hook in a project's settings

Three rules make the sum right, each measured on Claude Code 2.1.273: one API
message is written as one line per content block, each repeating the message id
and the usage, with `output_tokens` growing to its final count on the last block,
and a resumed or rewound session writes its earlier messages a second time (so a
message counts once per id, output as the largest seen); a subagent's calls live
only in its own file, never repeated by the parent (so summing every file counts
every call once); a `<synthetic>` message is an error or a limit notice with no
usage, and a limit notice names the window and the second it resets.

The scan is incremental: the first run reads everything (about a gigabyte in a
second or two), later runs only the files that grew, from where they stopped,
into per-hour, per-model sums in a cache kept outside `~/.claude`. Nothing here
writes into `~/.claude`; the meter file is Claude Code's own and is only read.

What the person is told is "about", never a decimal, never an absolute number
of tokens for the limit: Anthropic publishes none, and the meter is the only
truth. The line names /usage for the exact figure.
"""

import argparse
import datetime
import json
import os
import subprocess
import sys
import time
from pathlib import Path

# Python on Windows writes "\r\n" for every "\n", and the recipes compare what
# it says as text: "removed\r" is not "removed" (spec 020). LF on every machine;
# the encoding is PYTHONUTF8's, which core.just sets.
for _stream in (sys.stdout, sys.stderr):
    if hasattr(_stream, "reconfigure"):
        _stream.reconfigure(newline="\n")

HOME = Path.home()
# Every path can be pointed elsewhere, which is how the self-test keeps its hands
# off the real transcripts and the real meter.
PROJECTS = Path(os.environ.get("AI_BACKBONE_BUDGET_PROJECTS") or (HOME / ".claude" / "projects"))
METER = Path(os.environ.get("AI_BACKBONE_BUDGET_METER") or (HOME / ".claude.json"))
CACHE = Path(os.environ.get("AI_BACKBONE_BUDGET_CACHE") or (HOME / ".cache" / "ai-backbone" / "budget.json"))
CACHE_VERSION = 1
FIELDS = ("input", "cache_create", "cache_read", "output")
API_FIELDS = ("input_tokens", "cache_creation_input_tokens", "cache_read_input_tokens", "output_tokens")
DEFAULT_CAP = 8
DAYS_TR = ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"]
DAYS_EN = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]


def say(line=""):
    print(line, flush=True)


def empty_entry():
    # `ids` holds every message id the file has shown so far, because a repeat can
    # land after the offset a later run resumes from. Forty-six thousand ids over
    # a gigabyte of transcripts cost the cache about a megabyte.
    return {"size": 0, "mtime": 0, "offset": 0, "tail": None, "buckets": {}, "resets": {}, "ids": []}


def bucket_key(timestamp, model):
    # "2026-09-13T17:59:22.219Z"[:13] is the UTC hour. Slicing beats parsing a
    # hundred thousand timestamps, and an hour is fine grain enough: the one
    # weekly reset this machine has been told of fell exactly on an hour.
    return timestamp[:13] + "|" + model


def scan_file(path, entry):
    """Read a transcript from where the last run stopped and fold what it finds
    into the entry's per-hour buckets. Returns the number of lines read."""
    buckets = entry["buckets"]
    tail = entry["tail"]
    ids = set(entry["ids"])
    lines = 0
    with open(path, "rb") as fh:
        fh.seek(entry["offset"])
        for line in fh:
            lines += 1
            # Cheaper than parsing every line: only assistant records carry usage,
            # and a limit notice is one of them.
            if b'"assistant"' not in line:
                continue
            try:
                rec = json.loads(line)
            except ValueError:
                continue
            if rec.get("type") != "assistant":
                continue
            quota = rec.get("quotaLimits")
            if quota and quota.get("resetsAt") and quota.get("rateLimitType"):
                kind = quota["rateLimitType"]
                entry["resets"][kind] = max(entry["resets"].get(kind, 0), int(quota["resetsAt"]))
            message = rec.get("message") or {}
            model = message.get("model") or ""
            usage = message.get("usage") or {}
            if not model or model.startswith("<") or not usage:
                continue
            mid = message.get("id")
            timestamp = rec.get("timestamp") or ""
            if not mid or len(timestamp) < 13:
                continue
            values = [int(usage.get(k) or 0) for k in API_FIELDS]
            key = bucket_key(timestamp, model)
            if tail and tail[0] == mid:
                # Another block of the message counted a moment ago: only the
                # output can have grown, and only the growth is new.
                grown = values[3] - tail[2]
                if grown > 0:
                    buckets[tail[1]]["output"] += grown
                    tail[2] = values[3]
                continue
            if mid in ids:
                # The history written a second time. Already counted.
                continue
            ids.add(mid)
            bucket = buckets.get(key)
            if bucket is None:
                bucket = buckets[key] = {"msgs": 0, "input": 0, "cache_create": 0, "cache_read": 0, "output": 0}
            bucket["msgs"] += 1
            for name, value in zip(FIELDS, values):
                bucket[name] += value
            tail = [mid, key, values[3]]
    entry["tail"] = tail
    entry["ids"] = sorted(ids)
    entry["offset"] = os.path.getsize(path) if lines else entry["offset"]
    return lines


def load_cache(where):
    try:
        data = json.loads(where.read_text())
        if data.get("version") == CACHE_VERSION and isinstance(data.get("files"), dict):
            return data
    except (OSError, ValueError):
        pass
    return {"version": CACHE_VERSION, "files": {}}


def save_cache(where, data):
    # Written whole and renamed into place, so a run cut short leaves the last
    # good cache rather than half of a new one.
    try:
        where.parent.mkdir(parents=True, exist_ok=True)
        tmp = where.with_suffix(".tmp")
        tmp.write_bytes(json.dumps(data, separators=(",", ":")).encode("utf-8"))
        os.replace(tmp, where)
    except OSError as err:
        print(f"(could not keep the cache at {where}: {err})", file=sys.stderr)


def refresh(cache, projects, today_since=0.0):
    """Bring the cache up to date with the transcripts on disk. Returns
    (files seen, files read, lines read, subagent transcripts touched today)."""
    files = cache["files"]
    seen = set()
    read = 0
    lines = 0
    agents_today = 0
    for folder, _, names in os.walk(projects):
        for name in names:
            if not name.endswith(".jsonl"):
                continue
            path = os.path.join(folder, name)
            seen.add(path)
            try:
                st = os.stat(path)
            except OSError:
                continue
            # A subagent writes its own file; one written today is one started today.
            if name.startswith("agent-") and "subagents" in folder and st.st_mtime >= today_since:
                agents_today += 1
            entry = files.get(path)
            if entry and entry["size"] == st.st_size and entry["mtime"] == st.st_mtime:
                continue
            if not entry or st.st_size < entry["offset"] or (st.st_size == entry["size"] and entry["mtime"] != st.st_mtime):
                # New, truncated, or rewritten in place: what the cache holds for
                # it cannot be trusted, so it is read from the first byte.
                entry = files[path] = empty_entry()
            lines += scan_file(path, entry)
            entry["size"] = st.st_size
            entry["mtime"] = st.st_mtime
            read += 1
    # A transcript Claude Code cleaned up (30 days by default) takes its sums with it.
    for path in [p for p in files if p not in seen]:
        del files[path]
    return len(seen), read, lines, agents_today


def hour_of(key):
    """The UTC hour a bucket key stands for, as a datetime."""
    return datetime.datetime.strptime(key[:13], "%Y-%m-%dT%H").replace(tzinfo=datetime.timezone.utc)


def sum_window(cache, start, end):
    """Tokens between two aware datetimes, by field and by model. A bucket is an
    hour; the window is cut to whole hours, which the reset times on this machine
    (all on :00, :10, :20 or :40) can miss by at most one hour's worth."""
    by_field = {k: 0 for k in FIELDS}
    by_field["msgs"] = 0
    by_model = {}
    hours = {}
    for entry in cache["files"].values():
        for key, bucket in entry["buckets"].items():
            when = hours.get(key[:13])
            if when is None:
                when = hours[key[:13]] = hour_of(key)
            if not (start <= when < end):
                continue
            model = key[14:]
            row = by_model.setdefault(model, {k: 0 for k in FIELDS} | {"msgs": 0})
            for k in FIELDS:
                by_field[k] += bucket[k]
                row[k] += bucket[k]
            by_field["msgs"] += bucket["msgs"]
            row["msgs"] += bucket["msgs"]
    by_field["all"] = sum(by_field[k] for k in FIELDS)
    for row in by_model.values():
        row["all"] = sum(row[k] for k in FIELDS)
    return by_field, by_model



def told_reset(cache):
    """The latest weekly reset the transcripts have recorded, or None: a limit
    notice names the second it resets at, and that is the one anchor this
    machine has actually been told when there is no meter."""
    latest = 0
    for entry in cache["files"].values():
        latest = max(latest, entry["resets"].get("seven_day", 0))
    return datetime.datetime.fromtimestamp(latest, datetime.timezone.utc) if latest else None


def git_global(key, default=""):
    """One value from the person's global git config: per machine, in no
    repository, the way the place for second copies is kept."""
    try:
        done = subprocess.run(["git", "config", "--global", "--get", f"ai-backbone.{key}"],
                              capture_output=True, text=True, timeout=5)
        return done.stdout.strip() if done.returncode == 0 and done.stdout.strip() else default
    except (OSError, subprocess.SubprocessError):
        return default


def cap_setting():
    for raw in (os.environ.get("AI_BACKBONE_AGENT_CAP", ""), git_global("agent-cap")):
        if raw.isdigit():
            return int(raw)
    return DEFAULT_CAP


def meter():
    """The last plan-usage answer Claude Code cached, or None. Read only."""
    try:
        cached = json.loads(METER.read_text())["cachedUsageUtilization"]
        fetched = datetime.datetime.fromtimestamp(cached["fetchedAtMs"] / 1000, datetime.timezone.utc)
    except (OSError, ValueError, KeyError, TypeError):
        return None
    out = {"fetched": fetched, "age_minutes": max(0, round((datetime.datetime.now(datetime.timezone.utc) - fetched).total_seconds() / 60))}
    for window in ("five_hour", "seven_day"):
        row = (cached.get("utilization") or {}).get(window) or {}
        if row.get("utilization") is None:
            continue
        resets = None
        try:
            resets = datetime.datetime.fromisoformat(str(row.get("resets_at")).replace("Z", "+00:00"))
        except (TypeError, ValueError):
            pass
        out[window] = {"used": max(0, min(100, int(round(float(row["utilization"]))))), "resets": resets}
    return out if "seven_day" in out else None


def working_days(start, end, weekend_rest):
    """Days between two moments, counted as a person works them: fractions of a
    day, and none on Saturday or Sunday when the person rests then."""
    total = 0.0
    cursor = start
    while cursor < end:
        next_day = datetime.datetime.combine(cursor.date() + datetime.timedelta(days=1), datetime.time(0), tzinfo=cursor.tzinfo)
        stop = min(next_day, end)
        if not (weekend_rest and cursor.weekday() >= 5):
            total += (stop - cursor).total_seconds() / 86400
        cursor = stop
    return total


def estimate(now, cache, gauge, week_start):
    """The week's percent as far as this machine can tell: the meter, plus what
    the transcripts saw since it was read, at the rate the meter implied. Never
    more than 25 points on top, and only when the meter is over an hour old."""
    used = gauge["seven_day"]["used"]
    fetched = gauge["fetched"]
    if gauge["age_minutes"] <= 60 or used < 3:
        return used, 0
    before, _ = sum_window(cache, week_start, fetched)
    since, _ = sum_window(cache, fetched, now + datetime.timedelta(hours=1))
    if before["all"] <= 0 or since["all"] <= 0:
        return used, 0
    added = min(25, since["all"] / (before["all"] / used))
    shown = min(100, int(round(used + added)))
    return shown, shown - used


def today_cap(n):
    """Write the day's number where the hook reads it, so that what the line says
    is what is enforced. The hook takes it after a session's own cap and the
    environment, before the machine setting; it is never above that setting,
    because it is derived from it. Rewritten at every session start."""
    try:
        folder = Path(os.environ.get("TMPDIR") or "/tmp") / "ai-backbone-agents"
        folder.mkdir(parents=True, exist_ok=True)
        tmp = folder / "today-cap.tmp"
        tmp.write_bytes(f"{int(n)}\n".encode("utf-8"))
        os.replace(tmp, folder / "today-cap")
    except OSError:
        pass


def line(lang, now, cache, gauge, week_start, week_end, agents_today):
    """The sentence a session starts with. Plain words, "about", the cap."""
    tr = lang == "tr"
    cap = cap_setting()
    rest = git_global("weekend", "rest") != "work"
    if gauge is None:
        today_cap(cap)
        return ("Omurgadan not: Claude'un kullanım ölçeri bu makinede henüz yok (bir kez /usage yazınca oluşur). "
                f"Bugün sormadan en fazla {cap} alt ajan." if tr else
                f"Backbone note: Claude's usage meter is not on this machine yet (typing /usage once creates it). "
                f"At most {cap} subagents today without asking.")
    if gauge.get("stale"):
        age_h = max(1, gauge["age_minutes"] // 60)
        today_cap(cap)
        return (f"Yeni hafta: ölçer sıfırlanmadan önce okunmuş ({age_h} saat önce), bu haftanın kullanımı henüz bilinmiyor; bir kez /usage yazınca yenilenir. Bugün sormadan en fazla {cap} alt ajan." if tr else
                f"New week: the meter was read before the reset ({age_h} h ago), so this week's usage is not known yet; typing /usage once refreshes it. At most {cap} subagents today without asking.")
    used, added = estimate(now, cache, gauge, week_start)
    five = gauge.get("five_hour")
    resets = gauge["seven_day"]["resets"] or week_end
    resets_local = resets.astimezone(now.tzinfo)
    days_left = max(0.0, (resets - now).total_seconds() / 86400)
    wd_left = working_days(now, resets_local, rest)
    wd_total = working_days(resets_local - datetime.timedelta(days=7), resets_local, rest) or 7
    expected = 100 * (1 - wd_left / wd_total) if wd_total else 0
    share = (100 - used) / wd_left if wd_left >= 1 else (100 - used)
    suggest = cap
    if used >= 90:
        suggest = 1
    elif used - expected > 15:
        suggest = max(1, cap // 2)
    today_cap(suggest)
    age = gauge["age_minutes"]
    days = DAYS_TR if tr else DAYS_EN
    when = f"{days[resets_local.weekday()]} {resets_local.strftime('%H:%M')}"
    if tr:
        age_s = "ölçer az önce" if age < 5 else (f"ölçer {age} dk önce" if age < 120 else f"ölçer {age // 60} saat önce")
        if added:
            age_s += f", o zamandan beri yaklaşık +%{added}"
        head = "Yeni hafta: " if used <= 3 and days_left >= 6.5 else ("Dikkat: " if used >= 80 else "Omurgadan not: ")
        s = (f"{head}haftalık kullanım yaklaşık %{used} ({age_s})"
             + (f", 5 saatlik pencere %{five['used']}" if five else "")
             + f". Sıfırlanma {when}, {days_left:.0f} gün" + (f" ({wd_left:.0f} iş günü)" if rest else "") + f" kaldı; günlük pay yaklaşık %{share:.0f}."
             + (f" Bugün bu makinede {agents_today} alt ajan çalıştı;" if agents_today else " Bugün")
             + f" sormadan {'en fazla ' if suggest < cap else ''}{suggest} alt ajana kadar.")
        if five and five["used"] >= 80:
            s += f" 5 saatlik pencere dolmak üzere; {five['resets'].astimezone(now.tzinfo).strftime('%H:%M') if five['resets'] else 'birazdan'} sıfırlanır."
        s += " (Tahmindir; modele ve ajanlara göre değişir. Kesin sayı: /usage)"
    else:
        age_s = "meter read just now" if age < 5 else (f"meter read {age} min ago" if age < 120 else f"meter read {age // 60} h ago")
        if added:
            age_s += f", about +{added}% since"
        head = "New week: " if used <= 3 and days_left >= 6.5 else ("Careful: " if used >= 80 else "Backbone note: ")
        s = (f"{head}about {used}% of the week's limit used ({age_s})"
             + (f", five-hour window {five['used']}%" if five else "")
             + f". Resets {when}, {days_left:.0f} days" + (f" ({wd_left:.0f} working days)" if rest else "") + f" left; about {share:.0f}% a day."
             + (f" {agents_today} subagents ran on this machine today;" if agents_today else " Today")
             + f" up to {suggest} subagents without asking.")
        if five and five["used"] >= 80:
            s += f" The five-hour window is nearly full; it resets at {five['resets'].astimezone(now.tzinfo).strftime('%H:%M') if five['resets'] else 'shortly'}."
        s += " (An estimate; it varies with the models and agents used. The exact figure: /usage)"
    return s


# ─── the hook in a project's settings ────────────────────────────────────────
HOOK_COMMAND = 'bash "$CLAUDE_PROJECT_DIR"/.ai-backbone/agent-cap.sh'
HOOK_GROUP = {"matcher": "Agent|Workflow", "hooks": [{"type": "command", "command": HOOK_COMMAND}]}


def _mine(group):
    return any("agent-cap.sh" in str(h.get("command", "")) for h in group.get("hooks", []))


def _load_settings(path):
    if not os.path.exists(path) or os.path.getsize(path) == 0:
        return {}
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def _save_settings(path, data):
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8", newline="\n") as fh:  # LF on Windows too (spec 020)
        json.dump(data, fh, indent=2, ensure_ascii=False)
        fh.write("\n")
    os.replace(tmp, path)


def hook(action, path):
    """Add, remove or check the one PreToolUse group the backbone owns, recognised
    by its command; every other key, hook and permission is left as found, and
    the group is never added twice (measured on twelve shapes of settings.json)."""
    if action == "check":
        try:
            groups = _load_settings(path).get("hooks", {}).get("PreToolUse", [])
        except (OSError, ValueError):
            return 1
        return 0 if any(_mine(g) for g in groups) else 1
    data = _load_settings(path)
    if action == "add":
        groups = data.setdefault("hooks", {}).setdefault("PreToolUse", [])
        mine = [g for g in groups if _mine(g)]
        if mine:
            if len(mine) == 1 and mine[0].get("matcher") == HOOK_GROUP["matcher"]:
                say("already there"); return 0
            # An older copy, or two: one group, with the wider matcher. Two of them
            # counted every call twice and halved the cap (measured in review).
            mine[0]["matcher"] = HOOK_GROUP["matcher"]
            data["hooks"]["PreToolUse"] = [g for g in groups if not _mine(g)] + mine[:1]
            _save_settings(path, data); say("updated"); return 0
        groups.append(json.loads(json.dumps(HOOK_GROUP)))
        _save_settings(path, data); say("added"); return 0
    groups = data.get("hooks", {}).get("PreToolUse")
    if not groups or not any(_mine(g) for g in groups):
        say("not there"); return 0
    kept = [g for g in groups if not _mine(g)]
    if kept:
        data["hooks"]["PreToolUse"] = kept
    else:
        del data["hooks"]["PreToolUse"]
        if not data["hooks"]:
            del data["hooks"]
    _save_settings(path, data); say("removed"); return 0


def fmt(n):
    return f"{n:,}"


def main():
    argv = sys.argv[1:]
    if argv[:1] == ["hook"]:
        action = argv[1] if len(argv) > 1 else "add"
        if action not in ("add", "remove", "check"):
            say("budget.py hook add|remove|check [.claude/settings.json]"); return 2
        return hook(action, argv[2] if len(argv) > 2 else os.path.join(".claude", "settings.json"))
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--line", metavar="LANG", help="one line for the start of a session, tr or en; never fails")
    parser.add_argument("--json", action="store_true", help="print one JSON object instead of text")
    args = parser.parse_args(argv)
    if args.line:
        try:
            return report(args, args.line)
        except Exception as err:  # noqa: BLE001 — a session must never fail for this line
            cap = cap_setting()
            say(f"Omurgadan not: kullanım ölçülemedi ({type(err).__name__}); sormadan en fazla {cap} alt ajan." if args.line == "tr"
                else f"Backbone note: usage could not be measured ({type(err).__name__}); at most {cap} subagents without asking.")
            return 0
    return report(args, "")


def report(args, lang):
    started = time.time()
    now = datetime.datetime.now().astimezone()
    today_start = datetime.datetime.combine(now.date(), datetime.time(0), tzinfo=now.tzinfo)
    gauge = meter()
    cache = load_cache(CACHE)
    seen = read = lines = agents_today = 0
    if PROJECTS.is_dir():
        seen, read, lines, agents_today = refresh(cache, PROJECTS, today_start.timestamp())
        save_cache(CACHE, cache)
    # The week anchor: the meter's own reset, else the last limit notice seen,
    # else the most recent Monday 05:00, which is where this machine's fell.
    if gauge and gauge["seven_day"]["resets"]:
        week_end = gauge["seven_day"]["resets"].astimezone(now.tzinfo)
        if week_end <= now:
            # Read before the reset: the first session of every week, until Claude
            # Code refetches. Its percent is last week's, and this week's is unknown.
            gauge["stale"] = True
            while week_end <= now:
                week_end += datetime.timedelta(days=7)
            gauge["seven_day"]["resets"] = week_end
    else:
        told = told_reset(cache)
        if told:
            week_end = told.astimezone(now.tzinfo)
            while week_end <= now:
                week_end += datetime.timedelta(days=7)
        else:
            day = now.date() - datetime.timedelta(days=now.weekday())
            week_end = datetime.datetime.combine(day, datetime.time(5), tzinfo=now.tzinfo)
            if week_end <= now:
                week_end += datetime.timedelta(days=7)
    week_start = week_end - datetime.timedelta(days=7)
    if lang:
        say(line(lang, now, cache, gauge, week_start, week_end, agents_today))
        return 0
    week, week_models = sum_window(cache, week_start, now + datetime.timedelta(hours=1))
    today, today_models = sum_window(cache, today_start, now + datetime.timedelta(hours=1))
    days = []
    for i in range(7):
        a = week_start + datetime.timedelta(days=i)
        if a > now:
            break
        total, _ = sum_window(cache, a, a + datetime.timedelta(days=1))
        days.append({"from": a.isoformat(timespec="minutes"), **total})
    result = {
        "week_start": week_start.isoformat(timespec="minutes"), "week_end": week_end.isoformat(timespec="minutes"),
        "now": now.isoformat(timespec="seconds"), "days_to_reset": round((week_end - now).total_seconds() / 86400, 2),
        "meter": None if gauge is None else {
            "age_minutes": gauge["age_minutes"],
            "seven_day": {"used_percent": gauge["seven_day"]["used"], "resets_at": gauge["seven_day"]["resets"].isoformat() if gauge["seven_day"]["resets"] else None},
            "five_hour": None if "five_hour" not in gauge else {"used_percent": gauge["five_hour"]["used"], "resets_at": gauge["five_hour"]["resets"].isoformat() if gauge["five_hour"]["resets"] else None}},
        "estimate_percent": estimate(now, cache, gauge, week_start)[0] if gauge and not gauge.get("stale") else None,
        "cap": cap_setting(), "weekend": git_global("weekend", "rest"), "agents_today": agents_today,
        "week": week, "week_by_model": week_models, "week_by_day": days, "today": today, "today_by_model": today_models,
        "files": seen, "files_read": read, "lines_read": lines, "seconds": round(time.time() - started, 3), "cache": str(CACHE),
    }
    if args.json:
        say(json.dumps(result, indent=1)); return 0
    say(line("en", now, cache, gauge, week_start, week_end, agents_today)); say()
    say(f"Week since {week_start.strftime('%a %Y-%m-%d %H:%M')}, resets {week_end.strftime('%a %Y-%m-%d %H:%M')} ({result['days_to_reset']} days); cap {result['cap']}, weekend {result['weekend']}")
    say(f"{'':14}{'messages':>10}{'input':>10}{'cache write':>14}{'cache read':>16}{'output':>12}{'all tokens':>16}")
    for label, row in (("this week", week), ("today", today)):
        say(f"{label:14}{fmt(row['msgs']):>10}{fmt(row['input']):>10}{fmt(row['cache_create']):>14}{fmt(row['cache_read']):>16}{fmt(row['output']):>12}{fmt(row['all']):>16}")
    say("this week by model")
    for model, row in sorted(week_models.items(), key=lambda kv: -kv[1]["all"]):
        say(f"  {model:28}{fmt(row['msgs']):>8} msgs  {fmt(row['all']):>16} tokens")
    say("this week by day")
    for d in days:
        say(f"  {d['from'][:10]}  {fmt(d['all']):>16} tokens  {fmt(d['msgs']):>7} msgs")
    say(f"{seen} transcripts, {read} read this run ({fmt(lines)} lines), {result['seconds']}s, cache {CACHE}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(130)
