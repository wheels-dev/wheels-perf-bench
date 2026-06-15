#!/usr/bin/env bash
#
# Cross-engine profiling harness for the Wheels performance benchmark app.
#
# Measures the three costs that matter for a CFML MVC framework:
#   - dispatch-only  (/ping)      framework per-request overhead, no ORM
#   - ORM list       (/posts)     findAll over 100 rows + view loop
#   - ORM single     (/posts/1)   findByKey single record
#
# It speaks only HTTP, so it works against ANY engine serving the app —
# Lucee, Adobe ColdFusion, BoxLang, or RustCFML. Point it at the running
# server's base URL.
#
# Usage:
#   bench/bench.sh [BASE_URL] [ENGINE_LABEL]
#     BASE_URL       default http://localhost:8080
#     ENGINE_LABEL   free-text tag for the output, e.g. lucee7 / boxlang / rustcfml
#
#   BENCH_ITER=500 bench/bench.sh http://localhost:8080 boxlang
#
# COLD vs WARM:
#   The first request to a freshly started server pays a one-time
#   CFML->bytecode compile (often the bulk of "startup" latency). To capture
#   it, (re)start the server and run this script immediately — the COLD row is
#   then meaningful. Run it again for steady-state WARM numbers.
#
set -euo pipefail

BASE="${1:-http://localhost:8080}"
LABEL="${2:-${BENCH_ENGINE:-unknown}}"
ITER="${BENCH_ITER:-200}"

ENDPOINTS=("/ping" "/posts" "/posts/1")
DESCS=("dispatch-only (no ORM)" "ORM list (100 rows)" "ORM single record")

ctime() { curl -s -o /dev/null -w '%{time_total}' "$1"; }
ccode() { curl -s -o /dev/null -w '%{http_code}' "$1"; }

echo "=================================================================="
echo " Wheels perf benchmark"
echo "   engine : $LABEL"
echo "   base   : $BASE"
echo "   warm N : $ITER iterations/endpoint"
echo "=================================================================="

# Reachability check
if [ "$(ccode "$BASE/ping")" != "200" ]; then
  echo "ERROR: $BASE/ping did not return 200. Is the server up and the app reloaded?" >&2
  exit 1
fi

echo
echo "COLD (first hit after start — only meaningful right after a (re)start):"
printf '  %-10s %-24s %s\n' "ENDPOINT" "WHAT" "TIME / STATUS"
for i in "${!ENDPOINTS[@]}"; do
  ep="${ENDPOINTS[$i]}"
  t="$(ctime "$BASE$ep")"
  c="$(ccode "$BASE$ep")"
  printf '  %-10s %-24s %ss  http=%s\n' "$ep" "${DESCS[$i]}" "$t" "$c"
done

echo
echo "WARM ($ITER iterations each, serial curl — latency incl. client overhead):"
printf '  %-10s %-9s %-9s %-9s %-9s %-9s  %s\n' "ENDPOINT" "min" "p50" "p95" "max" "avg" "WHAT"
for i in "${!ENDPOINTS[@]}"; do
  ep="${ENDPOINTS[$i]}"
  # warm up the JIT / caches
  for w in 1 2 3 4 5; do curl -s -o /dev/null "$BASE$ep"; done
  # collect, sort, summarize (portable: sort -n + awk indexing, no gawk asort)
  stats="$(
    for ((n=0; n<ITER; n++)); do ctime "$BASE$ep"; echo; done \
      | sort -n \
      | awk -v ep="$ep" '
          { a[NR]=$1; s+=$1 }
          END {
            n=NR;
            printf "%.4f %.4f %.4f %.4f %.4f", a[1], a[int(n*0.5)], a[int(n*0.95)], a[n], s/n
          }'
  )"
  read -r mn p50 p95 mx avg <<<"$stats"
  printf '  %-10s %-9s %-9s %-9s %-9s %-9s  %s\n' "$ep" "$mn" "$p50" "$p95" "$mx" "$avg" "${DESCS[$i]}"
done

# Optional: truer throughput via Apache Bench if available
if command -v ab >/dev/null 2>&1; then
  echo
  echo "THROUGHPUT (Apache Bench, 2000 req / concurrency 8):"
  for ep in "/ping" "/posts"; do
    rps="$(ab -n 2000 -c 8 -l "$BASE$ep" 2>/dev/null | awk -F: '/Requests per second/{gsub(/^[ \t]+/,"",$2); print $2}')"
    printf '  %-10s %s\n' "$ep" "$rps"
  done
fi

echo
echo "Done. Re-run after a server restart to compare COLD numbers across engines."
