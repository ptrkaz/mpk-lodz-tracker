#!/usr/bin/env bash
# Fails if secrets.json is missing, not valid JSON, or any required key is
# empty / set to the placeholder "REPLACE_ME".
#
# Required keys are read from secrets.example.json (top-level keys only).
set -euo pipefail

FILE="${1:-secrets.json}"
TEMPLATE="${2:-secrets.example.json}"

if [[ ! -f "$FILE" ]]; then
  echo "error: $FILE not found. Copy $TEMPLATE and fill in values." >&2
  exit 1
fi

if ! python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$FILE" >/dev/null 2>&1; then
  echo "error: $FILE is not valid JSON." >&2
  exit 1
fi

python3 - "$FILE" "$TEMPLATE" <<'PY'
import json, sys
secrets_path, template_path = sys.argv[1], sys.argv[2]
secrets = json.load(open(secrets_path))
template = json.load(open(template_path))
missing = []
for key in template:
    val = secrets.get(key)
    if val in (None, "", "REPLACE_ME"):
        missing.append(key)
if missing:
    print(f"error: {secrets_path} has empty or placeholder values for: "
          + ", ".join(missing), file=sys.stderr)
    sys.exit(1)
PY

echo "ok: $FILE has all required keys"
