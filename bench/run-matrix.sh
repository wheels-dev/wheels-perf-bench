#!/usr/bin/env bash
#
# Cross-engine performance matrix runner.
#
# Starts the benchmark app on each requested CFML engine, runs bench/bench.sh
# against it, captures per-engine output under results/, and writes an aggregated
# results/SUMMARY.md. Designed to run locally and in CI (see
# .github/workflows/perf-matrix.yml, which calls this one engine at a time).
#
# Usage:
#   bench/run-matrix.sh [engine ...]
#     engines: lucee7 rustcfml boxlang adobe2023   (default: lucee7 rustcfml)
#
# Engine prerequisites (each is optional — a missing one is reported as skipped):
#   lucee7     the `wheels` CLI on PATH (serves on :8080)
#   rustcfml   RUSTCFML_BIN env var pointing at a rustcfml binary (serves on :8600)
#   boxlang    CommandBox `box` on PATH (cfengine=boxlang@1.11.0+48, :8700)
#   adobe2023  CommandBox `box` on PATH (cfengine=adobe@2023, :8800)
#
# Env:
#   BENCH_ITER   iterations per warm endpoint (default 120)
#   RUSTCFML_BIN path to the rustcfml binary (no default — rustcfml skipped if unset)
#
set -uo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS="$APP_DIR/results"
WEBROOT="$APP_DIR/public"
SQLITE_JAR_DIR="$APP_DIR/plugins/sqlite-driver/lib"   # loaded onto JVM engines via this.javaSettings
export BENCH_ITER="${BENCH_ITER:-120}"

ENGINES=("${@:-}")
[ -z "${ENGINES[*]}" ] && ENGINES=(lucee7 rustcfml)

mkdir -p "$RESULTS"
: > "$RESULTS/SUMMARY.md"

log() { printf '\033[36m[matrix]\033[0m %s\n' "$*"; }
warn() { printf '\033[33m[matrix]\033[0m %s\n' "$*"; }

# Wait until BASE/ping returns any HTTP status (server is accepting requests).
wait_up() {
  local base="$1" tries="${2:-60}"
  for ((i = 0; i < tries; i++)); do
    [ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$base/ping" 2>/dev/null)" != "000" ] && return 0
    sleep 2
  done
  return 1
}

# Run the benchmark against a running engine and record the outcome.
#   $1 engine label   $2 base url
measure() {
  local engine="$1" base="$2" out="$RESULTS/$1.txt"
  if ! wait_up "$base"; then
    warn "$engine: server never came up at $base — skipping"
    echo "- **$engine** — server did not start" >> "$RESULTS/SUMMARY.md"
    return 1
  fi
  local code
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 30 "$base/posts" 2>/dev/null)"
  if [ "$code" != "200" ]; then
    warn "$engine: /posts returned $code (engine cannot serve the app) — recording blocked"
    { echo "ENGINE: $engine"; echo "STATUS: BLOCKED (/posts http=$code)"; } > "$out"
    echo "- **$engine** — BLOCKED (/posts http=$code; see results/$engine.txt)" >> "$RESULTS/SUMMARY.md"
    return 1
  fi
  log "$engine: serving — benchmarking"
  bash "$APP_DIR/bench/bench.sh" "$base" "$engine" | tee "$out"
  # pull the warm p50 line for each endpoint into the summary
  {
    echo "- **$engine** — warm p50 (s): "
    # only the WARM table rows (3rd column is the numeric p50; COLD/WHAT rows are skipped)
    awk '/^  \/(ping|posts|posts\/1) / && $3 ~ /^[0-9.]+$/ {printf "    - %s: %s\n", $1, $3}' "$out"
  } >> "$RESULTS/SUMMARY.md"
}

start_rustcfml() {
  [ -n "${RUSTCFML_BIN:-}" ] && [ -x "${RUSTCFML_BIN:-}" ] || { warn "rustcfml: RUSTCFML_BIN unset/not executable — skipping"; return 1; }
  RUSTCFML_PRODUCTION=1 "$RUSTCFML_BIN" --serve "$WEBROOT" --port 8600 --production >"$RESULTS/rustcfml.server.log" 2>&1 &
  local pid=$!
  disown "$pid" 2>/dev/null || true
  measure rustcfml "http://localhost:8600"
  kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null || true
}

start_commandbox_engine() {
  local engine="$1" cfengine="$2" port="$3"
  command -v box >/dev/null 2>&1 || { warn "$engine: CommandBox `box` not found — skipping"; return 1; }
  local cfg="/tmp/perf-bench-$engine.server.json"
  cat > "$cfg" <<JSON
{ "name":"perf-bench-$engine",
  "web":{ "webroot":"$WEBROOT", "http":{"port":$port},
    "rewrites":{ "enable":true, "config":"$WEBROOT/urlrewrite.xml" } },
  "app":{ "cfengine":"$cfengine" }, "openbrowser":false }
JSON
  box server stop serverConfigFile="$cfg" >/dev/null 2>&1 || true
  box server start serverConfigFile="$cfg" >/dev/null 2>&1
  measure "$engine" "http://localhost:$port"
  box server stop serverConfigFile="$cfg" >/dev/null 2>&1 || true
}

log "engines: ${ENGINES[*]}  (iterations=$BENCH_ITER)"
echo "# Cross-engine perf matrix" >> "$RESULTS/SUMMARY.md"
echo >> "$RESULTS/SUMMARY.md"
for engine in "${ENGINES[@]}"; do
  case "$engine" in
    lucee7)    start_commandbox_engine lucee7 "lucee@7" 8080 ;;
    rustcfml)  start_rustcfml ;;
    boxlang)   start_commandbox_engine boxlang "boxlang@1.11.0+48" 8700 ;;
    adobe2023) start_commandbox_engine adobe2023 "adobe@2023" 8800 ;;
    *)         warn "unknown engine: $engine" ;;
  esac
done

log "done — per-engine output in results/, summary in results/SUMMARY.md"
cat "$RESULTS/SUMMARY.md"
