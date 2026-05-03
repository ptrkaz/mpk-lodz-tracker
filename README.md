# mpk_lodz_tracker

A new Flutter project.

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

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
