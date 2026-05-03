#!/usr/bin/env python3
"""
Build secrets.json from individual environment variables.

Required keys are the top-level keys of secrets.example.json. Each must
be present as an environment variable of the same name; missing or empty
values cause a non-zero exit.

Used in CI as the fallback path when SECRETS_JSON (the full JSON blob)
is not set.
"""
import json
import os
import sys
from pathlib import Path

TEMPLATE = Path("secrets.example.json")
OUTPUT = Path("secrets.json")


def main() -> int:
    if not TEMPLATE.exists():
        print(f"error: {TEMPLATE} not found", file=sys.stderr)
        return 1

    template = json.loads(TEMPLATE.read_text())
    out: dict[str, str] = {}
    missing: list[str] = []
    for key in template:
        val = os.environ.get(key, "")
        if not val:
            missing.append(key)
        out[key] = val

    if missing:
        print(
            "error: SECRETS_JSON not set and missing env vars: "
            + ", ".join(missing),
            file=sys.stderr,
        )
        return 1

    OUTPUT.write_text(json.dumps(out))
    print(f"ok: wrote {OUTPUT} with keys: {', '.join(out)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
