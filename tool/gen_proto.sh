#!/usr/bin/env bash
set -euo pipefail
# Requires: protoc on PATH, dart pub global activate protoc_plugin
OUT=lib/data/services/generated
mkdir -p "$OUT"
protoc \
  --dart_out="$OUT" \
  --proto_path=proto \
  proto/gtfs-realtime.proto
