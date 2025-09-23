#!/usr/bin/env python3
"""Stream Godot headless log output and emit AI_EVENT markers for known error patterns."""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
from pathlib import Path

ERROR_PATTERNS = {
    "parse_error": re.compile(r"Parse Error:"),
    "load_fail": re.compile(r"Failed to load script"),
    "missing_file": re.compile(r"File not found"),
    "runtime_function": re.compile(r"Invalid call"),
    "runtime_assert": re.compile(r"Condition \""),
}


def tail_file(path: Path, poll_interval: float = 0.25):
    """Yield lines appended to *path* in real time."""
    with path.open("r", encoding="utf-8", errors="replace") as handle:
        handle.seek(0, os.SEEK_END)
        while True:
            line = handle.readline()
            if not line:
                time.sleep(poll_interval)
                continue
            yield line


def parse_existing(path: Path):
    """Yield existing lines once and exit."""
    with path.open("r", encoding="utf-8", errors="replace") as handle:
        for line in handle:
            yield line


def emit_events(line: str) -> list[dict[str, str]]:
    events = []
    for key, pattern in ERROR_PATTERNS.items():
        if pattern.search(line):
            events.append({"type": key, "message": line.rstrip()})
            break
    return events


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("log_file", type=Path, help="Path to the Godot log file to monitor")
    parser.add_argument(
        "--follow",
        action="store_true",
        help="Continuously follow the log file (default)."
    )
    parser.add_argument(
        "--once",
        action="store_true",
        help="Parse log file once and exit (overrides --follow)."
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Emit a JSON summary when the script exits."
    )
    args = parser.parse_args()

    log_path = args.log_file
    if not log_path.exists():
        parser.error(f"Log file '{log_path}' does not exist.")

    follow_mode = False if args.once else True
    summary = []

    line_source = parse_existing(log_path) if args.once else tail_file(log_path)

    try:
        for line in line_source:
            sys.stdout.write(line)
            sys.stdout.flush()
            events = emit_events(line)
            if events:
                for event in events:
                    message = event["message"]
                    sys.stdout.write(f"AI_EVENT::error::{event['type']}::{message}\n")
                summary.extend(events)

            if args.once and not follow_mode:
                # In once mode, we only process existing lines.
                continue
    except KeyboardInterrupt:
        pass

    if args.json:
        sys.stdout.write(json.dumps({"errors": summary}, indent=2))
        sys.stdout.write("\n")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
