# Build-Time Secrets Strategy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move build-time secrets (currently just `MAPTILER_KEY`, with room to grow) out of inline `--dart-define` calls into a single gitignored JSON file consumed via `--dart-define-from-file`, mirroring the Android `local.properties` + CI-secrets pattern. Make local development a single bare `flutter run` — no flags — once setup is done.

**Architecture:** Use Flutter's built-in `--dart-define-from-file=<path>.json` flag (Flutter 3.7+). A local `secrets.json` at repo root holds all build-time secrets and is gitignored; `secrets.example.json` is committed as a template. Application code keeps reading values via `String.fromEnvironment(...)` — no Dart-side change. A small `tool/flutter` wrapper script transparently appends the flag for `run`/`build`/`test`/`drive`/`attach`/`profile` subcommands when `secrets.json` exists; combined with an opt-in `.envrc` (gitignored, copied from the committed `.envrc.example` template) doing `PATH_add tool`, the bare command `flutter run` from inside the repo automatically picks up the file. CI reconstructs `secrets.json` at build time with two ordered paths: prefer a single `SECRETS_JSON` GitHub Actions secret holding the entire JSON body; fall back to individual per-key env vars (e.g. `MAPTILER_KEY`) if the blob is unset. The stale Expo-era `.env.example` is removed.

**Tech Stack:** Flutter ≥3.7 (`dart-define-from-file`), GitHub Actions, JSON, Bash, direnv (already in user's shell setup), Python 3 (preinstalled on the GitHub Actions Ubuntu runner and on macOS).

---

## File Structure

Created files:
- `secrets.example.json` — committed template; placeholder values, documents the schema. Used by `tool/check_secrets.sh` and `tool/build_secrets_from_env.py` as the authoritative list of required keys.
- `.envrc.example` — committed direnv template. One line: `PATH_add tool`. Users copy it to `.envrc` and `direnv allow`. The real `.envrc` is gitignored so user-specific tweaks (e.g. `dotenv`, extra `export FOO=...`) stay local.
- `tool/flutter` — Bash wrapper. For `run`/`build`/`test`/`drive`/`attach`/`profile`, appends `--dart-define-from-file=$repo/secrets.json` when the file exists and the user has not already passed that flag; otherwise passes through to the real flutter unchanged. For all other subcommands (e.g. `pub get`, `doctor`, `gen-l10n`), passes through unchanged.
- `tool/check_secrets.sh` — small dev guard that fails fast if `secrets.json` is missing or has empty/placeholder required keys. Used by docs and CI.
- `tool/build_secrets_from_env.py` — CI fallback helper. Reads required keys from `secrets.example.json`, pulls each from the environment, and writes `secrets.json`. Errors if any key is missing.
- `.github/workflows/build.yml` — CI workflow reconstructing `secrets.json` (blob-or-env-vars), running analyze/test/build, then shredding the file.

Modified files:
- `.gitignore` — add `/secrets.json` and `/.envrc` exclusions. Keep existing `.env*` rules (general defense in depth).
- `CLAUDE.md` — replace inline `--dart-define=MAPTILER_KEY=<key>` examples; describe the wrapper + direnv flow; update the "MAPTILER_KEY" sharp-edges entry.
- `README.md` — add "Local setup" section with the `cp` + `direnv allow` flow.
- `docs/manual-test.md` — update the run command.

Deleted files:
- `.env.example` — stale (references the old `EXPO_PUBLIC_MAPTILER_KEY` from the abandoned RN plan).

No application code changes. `String.fromEnvironment('MAPTILER_KEY', defaultValue: '')` in `lib/ui/features/map/views/map_screen.dart:24` keeps working unchanged: `--dart-define-from-file` populates the same compile-time environment table that `--dart-define` does.

---

### Task 1: Add the gitignored secrets file template

**Files:**
- Create: `secrets.example.json`
- Delete: `.env.example`

- [ ] **Step 1: Create the template file**

Write `secrets.example.json` with placeholder values. Use the literal string `REPLACE_ME` so empty/placeholder detection in the helper scripts is straightforward.

```json
{
  "MAPTILER_KEY": "REPLACE_ME"
}
```

- [ ] **Step 2: Delete the stale `.env.example`**

Run: `git rm .env.example`

Expected: file removed from index. The file references `EXPO_PUBLIC_MAPTILER_KEY` from the abandoned RN-era plan and is no longer used anywhere.

- [ ] **Step 3: Verify nothing references `.env.example` or `EXPO_PUBLIC_MAPTILER_KEY` in non-historical paths**

Run:
```bash
grep -rn "EXPO_PUBLIC_MAPTILER_KEY\|\.env\.example" \
  --exclude-dir=docs/superpowers/plans \
  --exclude-dir=docs/superpowers/specs \
  --exclude-dir=.git \
  .
```

Expected: no matches outside historical plan/spec docs (those are kept for history per `CLAUDE.md`).

- [ ] **Step 4: Commit**

```bash
git add secrets.example.json .env.example
git commit -m "chore(secrets): add secrets.example.json, remove stale .env.example"
```

---

### Task 2: Gitignore the real secrets file and the local `.envrc`

**Files:**
- Modify: `.gitignore`

- [ ] **Step 1: Append the rules**

Add the following block at the bottom of `.gitignore`, under the existing `# Project-specific` block (which already has `.env`, `.env*.local`, `.env.json`):

```gitignore
# Build-time secrets consumed via --dart-define-from-file=secrets.json.
# secrets.example.json IS committed; secrets.json is NOT.
/secrets.json

# Local direnv config. .envrc.example IS committed; .envrc is NOT, so
# user-specific tweaks (extra `export FOO=...`, `dotenv`, etc.) stay local.
/.envrc
```

- [ ] **Step 2: Create a real `secrets.json` locally and verify git ignores it**

Run:
```bash
cp secrets.example.json secrets.json
git status --porcelain
```

Expected: `secrets.json` does NOT appear in the output. `.gitignore` itself appears as modified.

- [ ] **Step 3: Verify `git check-ignore` confirms both rules**

Run:
```bash
git check-ignore -v secrets.json
touch .envrc && git check-ignore -v .envrc && rm .envrc
```

Expected: both lines print, each citing the matching rule in `.gitignore`.

- [ ] **Step 4: Commit the gitignore change**

```bash
git add .gitignore
git commit -m "chore(secrets): gitignore secrets.json and .envrc"
```

---

### Task 3: Add the dev-side guard script

**Files:**
- Create: `tool/check_secrets.sh`

This script is the "fail fast" check used by the docs and CI. It exits non-zero if `secrets.json` is missing, malformed, or contains placeholder values, so a build never silently succeeds with a blank MapTiler map.

- [ ] **Step 1: Write the script**

Write `tool/check_secrets.sh`:

```bash
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
```

- [ ] **Step 2: Make it executable**

Run: `chmod +x tool/check_secrets.sh`

- [ ] **Step 3: Verify failure path on the placeholder file**

Run: `./tool/check_secrets.sh secrets.example.json secrets.example.json`

Expected: exit code 1, message `error: secrets.example.json has empty or placeholder values for: MAPTILER_KEY`.

- [ ] **Step 4: Verify success path with a populated file**

Edit `secrets.json` so `MAPTILER_KEY` holds your real key (or any non-empty non-`REPLACE_ME` string for the test). Then:

Run: `./tool/check_secrets.sh`

Expected: exit code 0, message `ok: secrets.json has all required keys`.

- [ ] **Step 5: Verify failure when the file is missing**

Run:
```bash
mv secrets.json secrets.json.bak
./tool/check_secrets.sh; echo "exit=$?"
mv secrets.json.bak secrets.json
```

Expected: exit code 1, message `error: secrets.json not found. Copy secrets.example.json and fill in values.`

- [ ] **Step 6: Commit**

```bash
git add tool/check_secrets.sh
git commit -m "chore(secrets): add tool/check_secrets.sh guard"
```

---

### Task 4: Add the `tool/flutter` wrapper and `.envrc.example` for transparent local injection

**Files:**
- Create: `tool/flutter`
- Create: `.envrc.example`

The wrapper is the piece that lets you type `flutter run` (no flag) and have the build pick up `secrets.json` automatically. `.envrc.example` is the committed template — it puts `tool/` first in PATH inside the repo only, so the wrapper shadows the real `flutter` binary. The real `.envrc` (which the user produces by copying the template) is gitignored, so any per-developer additions stay local.

- [ ] **Step 1: Write the wrapper**

Write `tool/flutter`:

```bash
#!/usr/bin/env bash
# Wraps the real flutter binary. For build-related subcommands (run, build,
# test, drive, attach, profile), appends --dart-define-from-file=secrets.json
# when secrets.json exists at the repo root, unless the user has already
# passed --dart-define-from-file themselves. All other subcommands pass
# through unchanged.
#
# Activated via the committed .envrc (PATH_add tool) plus `direnv allow`.
# Inside the repo, bare `flutter run` resolves to this script.
set -euo pipefail

script_dir=$(cd "$(dirname "$0")" && pwd)

# Locate the real flutter binary by stripping this script's directory from PATH.
real_flutter=$(
  PATH=$(printf '%s' "$PATH" | tr ':' '\n' | grep -v -F -x "$script_dir" | paste -sd: -) \
  command -v flutter || true
)
if [[ -z "$real_flutter" ]]; then
  echo "tool/flutter: cannot find the real flutter binary in PATH (after stripping $script_dir)" >&2
  exit 127
fi

cmd="${1:-}"
inject=0
case "$cmd" in
  run|build|test|drive|attach|profile) inject=1 ;;
esac

if [[ "$inject" -eq 1 ]]; then
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
  secrets="$repo_root/secrets.json"
  # Only inject if (a) the file exists and (b) the user has not already passed the flag.
  if [[ -f "$secrets" && "$*" != *"--dart-define-from-file"* ]]; then
    exec "$real_flutter" "$@" --dart-define-from-file="$secrets"
  fi
fi

exec "$real_flutter" "$@"
```

- [ ] **Step 2: Make it executable**

Run: `chmod +x tool/flutter`

- [ ] **Step 3: Write `.envrc.example` (committed template)**

Write `.envrc.example` at repo root:

```bash
# Copy this file to .envrc, then run `direnv allow`.
# The real .envrc is gitignored — any per-developer additions stay local.
#
# direnv hooks PATH so tool/ shadows the real flutter binary inside this repo.
# After `direnv allow`, bare `flutter run` will auto-inject
# --dart-define-from-file=secrets.json via tool/flutter.
PATH_add tool
```

- [ ] **Step 4: Create the local `.envrc` and allow it**

Run:
```bash
cp .envrc.example .envrc
direnv allow
```

Expected: `direnv allow` prints something like `direnv: loading .envrc` and `direnv: export +PATH`. If direnv is not installed, install it (`brew install direnv`) and ensure your shell hook is set up — but per `~/CLAUDE.md` it already is.

Verify the real `.envrc` is gitignored:

Run: `git status --porcelain`

Expected: `.envrc` does NOT appear in the output. `.envrc.example` appears as a new untracked file.

- [ ] **Step 5: Verify the shadowing works**

Run: `which flutter`

Expected: the result ends with `/tool/flutter` (the wrapper), NOT `~/fvm/default/bin/flutter` or wherever fvm puts it.

Then verify the wrapper finds the real binary:

Run: `flutter --version`

Expected: prints the normal Flutter version output. (The wrapper passes `--version` through unchanged.)

- [ ] **Step 6: End-to-end smoke test — bare `flutter run`**

With `secrets.json` populated from Task 3 Step 4, run on an attached device:

Run: `flutter run`

Expected: app launches, the MapLibre map renders MapTiler tiles (NOT a blank/grey screen). If tiles load, the wrapper successfully appended `--dart-define-from-file=secrets.json` and `String.fromEnvironment('MAPTILER_KEY')` got populated.

If the map is blank: re-check `which flutter` (must point at the wrapper), and that `secrets.json` is valid JSON with a real key.

Stop the app with `q`.

- [ ] **Step 7: Verify pass-through for non-build subcommands**

Run: `flutter pub get`

Expected: pub get runs normally with no `--dart-define-from-file` flag (verified by the absence of any flag-related error and by the fact that pub-get does not accept that flag).

- [ ] **Step 8: Verify the wrapper does not double-inject**

Run: `flutter run --dart-define-from-file=secrets.json -d <device-id>` and let it start the build, then stop with `q` once "Running Gradle..." or equivalent appears.

Expected: build proceeds without a "duplicate flag" error from Flutter. (The wrapper detects the existing flag in `$*` and skips injection.)

- [ ] **Step 9: Commit (only the wrapper and the template, NOT the local `.envrc`)**

Verify what is staged before committing:

```bash
git add tool/flutter .envrc.example
git status --porcelain
```

Expected: only `tool/flutter` and `.envrc.example` appear under "Changes to be committed". The local `.envrc` MUST NOT appear (the gitignore rule from Task 2 keeps it out, but eyeball the diff to be sure).

```bash
git commit -m "feat(secrets): add tool/flutter wrapper + .envrc.example for transparent --dart-define-from-file injection"
```

---

### Task 5: Add the CI env-var fallback helper

**Files:**
- Create: `tool/build_secrets_from_env.py`

This script is used by the CI workflow when the `SECRETS_JSON` blob secret is not set — it reads the required keys from `secrets.example.json` and assembles `secrets.json` from individually-named env vars (e.g. a GitHub Actions secret called `MAPTILER_KEY` exposed to the step's `env:`).

- [ ] **Step 1: Write the script**

Write `tool/build_secrets_from_env.py`:

```python
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
```

- [ ] **Step 2: Make it executable**

Run: `chmod +x tool/build_secrets_from_env.py`

- [ ] **Step 3: Verify success path locally**

Run:
```bash
rm -f secrets.json
MAPTILER_KEY=fake_test_value ./tool/build_secrets_from_env.py
cat secrets.json
```

Expected:
- Exit code 0.
- Stdout: `ok: wrote secrets.json with keys: MAPTILER_KEY`.
- `cat secrets.json` shows `{"MAPTILER_KEY": "fake_test_value"}`.

- [ ] **Step 4: Verify failure path locally**

Run:
```bash
unset MAPTILER_KEY
./tool/build_secrets_from_env.py; echo "exit=$?"
```

Expected: exit code 1, message `error: SECRETS_JSON not set and missing env vars: MAPTILER_KEY`.

- [ ] **Step 5: Restore your real local `secrets.json`**

Run: edit `secrets.json` so `MAPTILER_KEY` holds your real key again (the test in Step 3 overwrote it).

- [ ] **Step 6: Commit**

```bash
git add tool/build_secrets_from_env.py
git commit -m "chore(secrets): add tool/build_secrets_from_env.py CI helper"
```

---

### Task 6: Update human-facing docs to the new flow

**Files:**
- Modify: `CLAUDE.md`
- Modify: `README.md`
- Modify: `docs/manual-test.md`

Do NOT touch `docs/superpowers/plans/*.md` or `docs/superpowers/specs/*.md`. Per `CLAUDE.md`, those are kept for history.

- [ ] **Step 1: Update `CLAUDE.md` Commands section**

Replace the two run/build lines:

Before:
```
- `flutter run --dart-define=MAPTILER_KEY=<key>` — debug build on attached device/emulator.
- `flutter build apk --dart-define=MAPTILER_KEY=<key>` — release APK.
```

After:
```
- First-time setup: `cp secrets.example.json secrets.json` (fill `MAPTILER_KEY` with a real value from https://cloud.maptiler.com/account/keys/), then `cp .envrc.example .envrc && direnv allow`. After that, the `tool/flutter` wrapper auto-appends `--dart-define-from-file=secrets.json` for build subcommands. Both `secrets.json` and `.envrc` are gitignored.
- `./tool/check_secrets.sh` — verify `secrets.json` has all required keys filled in.
- `flutter run` — debug build on attached device/emulator. Wrapper injects the secrets file.
- `flutter build apk` — release APK. Wrapper injects the secrets file.
- `flutter run --dart-define-from-file=secrets.json` — explicit form (works without direnv / outside the repo).
```

- [ ] **Step 2: Update the `MAPTILER_KEY` sharp-edges entry in `CLAUDE.md`**

Replace the existing bullet:

Before:
```
- **MAPTILER_KEY.** Pass via `--dart-define=MAPTILER_KEY=...`. Missing/empty produces a blank map (HTTP 403 from MapTiler). Read inside the app via `String.fromEnvironment('MAPTILER_KEY')`. Do NOT commit the key.
```

After:
```
- **Build-time secrets via `secrets.json`.** All build-time secrets (currently just `MAPTILER_KEY`) live in `secrets.json` at repo root, consumed via `--dart-define-from-file=secrets.json`. `secrets.json` is gitignored; `secrets.example.json` is the committed template. The app reads values via `String.fromEnvironment('<KEY>')`. Missing/empty `MAPTILER_KEY` produces a blank map (HTTP 403 from MapTiler). Locally, `tool/flutter` (a Bash wrapper) auto-appends the flag for `run`/`build`/`test`/`drive`/`attach`/`profile`. To activate the wrapper, copy `.envrc.example` to `.envrc` and run `direnv allow`; both `.envrc` and `secrets.json` are gitignored. The wrapper skips injection if the user already passed the flag. On CI, `secrets.json` is reconstructed by `.github/workflows/build.yml`: it prefers a single `SECRETS_JSON` repo secret holding the entire JSON body, and falls back to `tool/build_secrets_from_env.py` which assembles the file from individual env vars matching the keys in `secrets.example.json` (e.g. a `MAPTILER_KEY` repo secret). Do NOT commit `secrets.json` or `.envrc`. To add a new build-time secret: add it to `secrets.example.json`, append it to `secrets.json` locally, set the matching CI secret (either update `SECRETS_JSON` or add an individual repo secret), and read it via `String.fromEnvironment('NEW_KEY')`.
```

- [ ] **Step 3: Update `docs/manual-test.md`**

Replace:
```
flutter run --dart-define=MAPTILER_KEY=<your_key> -d <device-id>
```

With:
```
flutter run -d <device-id>
```

If the surrounding paragraph mentions setting the key inline, replace it with: "Ensure `secrets.json` exists at repo root with a real `MAPTILER_KEY` (see `README.md` setup) and that you have run `direnv allow` once. The `tool/flutter` wrapper appends `--dart-define-from-file=secrets.json` automatically. Then:"

- [ ] **Step 4: Add a "Local setup" section to `README.md`**

Append (or insert before any existing build instructions) the following block. If `README.md` already has a Setup section, update it; otherwise add it under the project description:

````markdown
## Local setup

1. Copy the secrets template and fill in real values:

   ```bash
   cp secrets.example.json secrets.json
   ```

   Edit `secrets.json` and set `MAPTILER_KEY` to a real key from
   https://cloud.maptiler.com/account/keys/. `secrets.json` is gitignored.

2. Verify the file looks right:

   ```bash
   ./tool/check_secrets.sh
   ```

3. Set up direnv (one time per clone):

   ```bash
   cp .envrc.example .envrc
   direnv allow
   ```

   This puts `tool/` first in PATH inside the repo, so the `tool/flutter`
   wrapper shadows the real `flutter` binary and auto-appends
   `--dart-define-from-file=secrets.json` for build subcommands. The local
   `.envrc` is gitignored so you can add per-developer tweaks without
   touching the committed template.

4. Run the app:

   ```bash
   flutter run
   ```

   No flags needed. To bypass the wrapper (or if you do not use direnv), use
   the explicit form:

   ```bash
   flutter run --dart-define-from-file=secrets.json
   ```
````

- [ ] **Step 5: Sanity-check no stale `--dart-define=MAPTILER_KEY=` references remain in non-historical docs**

Run:
```bash
grep -rn -- "--dart-define=MAPTILER_KEY" \
  --exclude-dir=docs/superpowers/plans \
  --exclude-dir=docs/superpowers/specs \
  --exclude-dir=.git \
  .
```

Expected: no matches (the only remaining references should be in the historical plans/specs, which we deliberately skip).

- [ ] **Step 6: Commit**

```bash
git add CLAUDE.md README.md docs/manual-test.md
git commit -m "docs(secrets): switch to wrapper + secrets.json flow"
```

---

### Task 7: Add the GitHub Actions workflow with blob-or-env-vars CI path

**Files:**
- Create: `.github/workflows/build.yml`

The workflow tries `SECRETS_JSON` first; if unset, falls back to `tool/build_secrets_from_env.py` which reads each required key from its own env var (mapped from per-key repo secrets). Either path produces an identical `secrets.json`.

- [ ] **Step 1: Create the workflow file**

Write `.github/workflows/build.yml`:

```yaml
name: build

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  analyze-test-build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true

      - name: Reconstruct secrets.json
        env:
          SECRETS_JSON: ${{ secrets.SECRETS_JSON }}
          MAPTILER_KEY: ${{ secrets.MAPTILER_KEY }}
        run: |
          set -euo pipefail
          if [[ -n "${SECRETS_JSON:-}" ]]; then
            printf '%s' "$SECRETS_JSON" > secrets.json
            echo "secrets.json built from SECRETS_JSON blob"
          else
            python3 tool/build_secrets_from_env.py
          fi

      - name: Verify secrets.json
        run: ./tool/check_secrets.sh

      - name: flutter pub get
        run: flutter pub get

      - name: flutter analyze
        run: flutter analyze

      - name: flutter test
        run: flutter test

      - name: flutter build apk
        run: flutter build apk --dart-define-from-file=secrets.json

      - name: Shred secrets.json
        if: always()
        run: rm -f secrets.json
```

Notes for the engineer:
- The `Shred secrets.json` step uses `if: always()` so the file is removed even on failure. The runner is ephemeral, but this stops accidental upload if a future step adds artifact archiving.
- `printf '%s'` (not `echo`) preserves the JSON exactly without appending a trailing newline that some strict parsers reject.
- The `flutter build apk` step uses the explicit `--dart-define-from-file=secrets.json` flag (not the wrapper) because CI does not load `.envrc`. This is intentional; the wrapper is a local-developer convenience, not part of the build contract.
- Do NOT use `set -x` or `cat secrets.json` anywhere — that would print the secret to logs. (GitHub auto-masks values stored in repo secrets, but eyeball the diff anyway.)
- To add a new secret on the env-var path: add it to `secrets.example.json` AND add a matching key to the `env:` map of the "Reconstruct secrets.json" step (e.g. `NEW_KEY: ${{ secrets.NEW_KEY }}`). The blob path (`SECRETS_JSON`) needs no workflow change.

- [ ] **Step 2: Configure CI secrets on GitHub (pick one or both paths)**

This is a manual step — there is no CLI for the engineer to run inside the worktree. Pick the path you prefer; both can coexist (blob wins).

Option A — blob (one secret, simpler):
```bash
gh secret set SECRETS_JSON < secrets.json
```

Option B — individual env vars (per-key rotation, easier audit):
```bash
gh secret set MAPTILER_KEY  # paste the value when prompted
```

Verify with: `gh secret list`. At least one of `SECRETS_JSON` or `MAPTILER_KEY` must be set.

- [ ] **Step 3: Commit and push to trigger the workflow**

```bash
git add .github/workflows/build.yml
git commit -m "ci: add build workflow with blob-or-env-vars secrets reconstruction"
git push
```

- [ ] **Step 4: Verify the workflow run**

Run: `gh run list --workflow=build.yml --limit 1`

Then: `gh run view <run-id> --log` for the latest run.

Expected:
- `Reconstruct secrets.json` step succeeds. The log line either says `secrets.json built from SECRETS_JSON blob` or `ok: wrote secrets.json with keys: MAPTILER_KEY` depending on which path you set up in Step 2.
- `Verify secrets.json` prints `ok: secrets.json has all required keys`.
- `flutter analyze`, `flutter test`, and `flutter build apk` all pass.
- `Shred secrets.json` step runs at the end.
- The raw `MAPTILER_KEY` value does NOT appear anywhere in the log.

If you want extra confidence in the fallback path, temporarily delete `SECRETS_JSON` (`gh secret delete SECRETS_JSON`), keep the `MAPTILER_KEY` repo secret, and re-run the workflow with `gh run rerun <run-id>` — it should still succeed via the env-var path.

---

### Task 8: Final verification sweep

No files change. This is the end-to-end sanity check before declaring the plan complete.

- [ ] **Step 1: Confirm `secrets.json` is not tracked**

Run: `git ls-files | grep -E '^secrets\.json$' || echo "not tracked (good)"`

Expected: `not tracked (good)`.

- [ ] **Step 2: Confirm `secrets.example.json` IS tracked**

Run: `git ls-files | grep -E '^secrets\.example\.json$'`

Expected: prints `secrets.example.json`.

- [ ] **Step 2a: Confirm `.envrc` is NOT tracked and `.envrc.example` IS tracked**

Run:
```bash
git ls-files | grep -E '^\.envrc$' || echo ".envrc not tracked (good)"
git ls-files | grep -E '^\.envrc\.example$'
```

Expected: first line prints `.envrc not tracked (good)`; second line prints `.envrc.example`.

- [ ] **Step 3: Confirm there are no leftover `--dart-define=MAPTILER_KEY=` references in non-historical files**

Run:
```bash
grep -rn -- "--dart-define=MAPTILER_KEY" \
  --exclude-dir=docs/superpowers/plans \
  --exclude-dir=docs/superpowers/specs \
  --exclude-dir=.git \
  . || echo "clean"
```

Expected: `clean`.

- [ ] **Step 4: Confirm the historical plan/spec mentions are still present (we deliberately did not touch them)**

Run:
```bash
grep -rn -- "--dart-define=MAPTILER_KEY" docs/superpowers/ | wc -l
```

Expected: a non-zero count (these are the history files; leaving them is intentional).

- [ ] **Step 5: Confirm `which flutter` resolves to the wrapper**

Run: `which flutter`

Expected: result ends with `/tool/flutter`. If not, run `direnv allow` and retry.

- [ ] **Step 6: Re-run the local toolchain — bare commands only**

Run:
```bash
./tool/check_secrets.sh
flutter analyze
flutter test
```

Expected: all three pass. (`flutter analyze` and `flutter test` go through the wrapper; the wrapper does not inject for `analyze` and does inject for `test` — both should pass.)

- [ ] **Step 7: Confirm the latest CI run on the branch is green**

Run: `gh run list --branch "$(git branch --show-current)" --limit 1`

Expected: most recent run shows `completed` / `success`.

---

## Adding new secrets later

(Doc-only reminder — not a step.)

To add a new build-time secret `FOO_API_KEY`:

1. Add it to `secrets.example.json` with `"FOO_API_KEY": "REPLACE_ME"`.
2. Add the real value to your local `secrets.json`.
3. Update CI:
   - Blob path: `gh secret set SECRETS_JSON < secrets.json` (replaces the whole blob, no workflow edit).
   - Env-var path: `gh secret set FOO_API_KEY` and add `FOO_API_KEY: ${{ secrets.FOO_API_KEY }}` to the `env:` map of the "Reconstruct secrets.json" step in `.github/workflows/build.yml`.
4. Read it in Dart: `const fooKey = String.fromEnvironment('FOO_API_KEY', defaultValue: '');`.
