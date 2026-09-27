#!/usr/bin/env python3
"""Build a Globus Transfer API request with directory filter rules.

Globus CLI's `transfer --exclude` only filters files. The documented Transfer
API additionally supports type="dir", which excludes the complete subtree.
This helper uses only the standard library and never logs in or submits data.
https://docs.globus.org/api/transfer/task_submit/#filter_rules
"""
from __future__ import annotations

import argparse
import json


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    for option in ("source-collection", "source-path", "destination-collection", "destination-path", "label", "submission-id"):
        parser.add_argument(f"--{option}", required=True)
    parser.add_argument("--sync-level", choices=("exists", "size", "mtime", "checksum"))
    parser.add_argument("--exclude", action="append", default=[])
    parser.add_argument("--exclude-dir", action="append", default=[])
    args = parser.parse_args()
    request = {
        "DATA_TYPE": "transfer",
        "submission_id": args.submission_id,
        "source_endpoint": args.source_collection,
        "destination_endpoint": args.destination_collection,
        "label": args.label,
        "verify_checksum": True,
        "notify_on_succeeded": False,
        "notify_on_failed": False,
        "notify_on_inactive": False,
        "DATA": [{
            "DATA_TYPE": "transfer_item",
            "source_path": args.source_path,
            "destination_path": args.destination_path,
            "recursive": True,
        }],
        "filter_rules": [
            {"DATA_TYPE": "filter_rule", "method": "exclude", "name": pattern, "type": kind}
            for patterns, kind in ((args.exclude, "file"), (args.exclude_dir, "dir"))
            for pattern in patterns
        ],
    }
    if args.sync_level:
        request["sync_level"] = {"exists": 0, "size": 1, "mtime": 2, "checksum": 3}[args.sync_level]
    print(json.dumps(request, separators=(",", ":")))


if __name__ == "__main__":
    main()
