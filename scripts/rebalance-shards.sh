#!/usr/bin/env bash
# Prints a balanced SHARDS block for scripts/test-shard-map.sh from MEASURED suite times.
#
# Usage: scripts/rebalance-shards.sh <timing-suites.txt> <shard_count>
#   <timing-suites.txt>  written by scripts/run-tests-sharded.sh in its log directory.
#                        One line per suite: "<ms> <tests> <shard> <suite>".
#   <shard_count>        how many shards to pack the suites into.
#
# Method: longest-processing-time-first. Sort the suites by measured time, longest first. Put each
# suite into the shard with the least total time so far. A suite is never split, so the longest
# suite is a floor under the wall-clock time of any run: no shard count can beat it.
#
# Measure with the same number of busy processes as cores. A suite measured while 9 shards
# competed for 4 cores reads about twice too slow. A measurement run that uses one suite per shard
# and a job pool as large as the core count (SHARD_MAP_FILE + SHARD_JOBS, see run-tests-sharded.sh)
# gives times close to a solo run.
#
# Output: the SHARDS array, shards in descending order of estimated time (the runner starts shards
# in map order, so the longest shard starts first), and the estimate of every shard as a comment.
# The third field of each entry is the shard's alarm, a hang ceiling. It is 4 times the
# estimate, never below 600 s, because a loaded machine runs slower than the measurement.
#
# movement_fallback is not packed: it belongs to MERGE_SUITES, and the timing file does not
# contain it.

set -euo pipefail

TIMING_FILE="${1:?usage: rebalance-shards.sh <timing-suites.txt> <shard_count>}"
COUNT="${2:?usage: rebalance-shards.sh <timing-suites.txt> <shard_count>}"
if ! [[ "$COUNT" =~ ^[1-9][0-9]*$ ]]; then
  echo "FATAL: shard_count must be a positive integer, got '$COUNT'." >&2
  exit 1
fi
[[ -s "$TIMING_FILE" ]] || { echo "FATAL: '$TIMING_FILE' is missing or empty." >&2; exit 1; }
# More shards than suites would print empty entries such as "shard5||600", and
# scripts/check-shard-map.sh rejects those. The timing file has one row per suite and does not
# contain the MERGE_SUITES (movement_fallback), so its row count is below the registered count.
ROWS="$(grep -c . "$TIMING_FILE")"
if [[ "$COUNT" -gt "$ROWS" ]]; then
  echo "FATAL: shard_count $COUNT is more than the $ROWS suites in '$TIMING_FILE'." >&2
  exit 1
fi

sort -k1,1nr -k4,4 "$TIMING_FILE" | awk -v n="$COUNT" '
  { ms[NR] = $1; name[NR] = $4; total += $1 }
  END {
    for (b = 1; b <= n; b++) { load[b] = 0; list[b] = "" }
    for (i = 1; i <= NR; i++) {
      best = 1
      for (b = 2; b <= n; b++) if (load[b] < load[best]) best = b
      load[best] += ms[i]
      list[best] = list[best] (list[best] == "" ? "" : ",") name[i]
      count[best]++
    }
    # Order the shards by load, descending; ties by the original bin number.
    for (b = 1; b <= n; b++) order[b] = b
    for (i = 1; i <= n; i++) for (j = i + 1; j <= n; j++)
      if (load[order[j]] > load[order[i]]) { t = order[i]; order[i] = order[j]; order[j] = t }
    # A bin can stay empty: suites that measured 0 ms never raise the load of a bin, so they all land in
    # the same bin. An empty entry would fail scripts/check-shard-map.sh, so empty bins are left out.
    used = 0
    for (i = 1; i <= n; i++) if (count[order[i]] > 0) used++
    if (used < n) printf "NOTE: %d of %d shards would be empty and are left out.\n", n - used, n > "/dev/stderr"
    printf "# Packed by scripts/rebalance-shards.sh: %d suites, %.0f s of test time, %d shards.\n", NR, total / 1000, used
    printf "# Longest single suite: %.0f s (the floor under the wall-clock time).\n", ms[1] / 1000
    print "SHARDS=("
    shard_no = 0
    for (i = 1; i <= n; i++) {
      b = order[i]
      if (count[b] == 0) continue
      shard_no++
      # Sort the suite names inside a shard so the diff between two rebalances stays small.
      m = split(list[b], parts, ",")
      for (x = 1; x <= m; x++) for (y = x + 1; y <= m; y++)
        if (parts[y] < parts[x]) { t = parts[x]; parts[x] = parts[y]; parts[y] = t }
      joined = parts[1]
      for (x = 2; x <= m; x++) joined = joined "," parts[x]
      est = load[b] / 1000
      alarm = est * 4; if (alarm < 600) alarm = 600
      printf "  \"shard%d|%s|%d\"  # est %.0f s, %d suites\n", shard_no, joined, alarm + 0.999, est, count[b]
    }
    print ")"
  }'
