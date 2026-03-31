#!/usr/bin/env bash
# run.sh — Compile D benchmarks, measure compile time, save results to results.json.
#
# Usage:
#   ./run.sh [output_file]
#
# If no output file is given, results are written to results.json in the
# current directory.
#
# Requirements:
#   - dmd must be on PATH
#   - python3 must be on PATH (used only for the median calculation)

set -euo pipefail

OUTPUT_FILE="${1:-results.json}"
BENCHMARKS_DIR="$(cd "$(dirname "$0")/benchmarks" && pwd)"
RUNS=3

# ---------------------------------------------------------------------------
# Helper: measure compile time for a single source file (in milliseconds).
# Compiles to a temporary output file so the build artefact is discarded.
# ---------------------------------------------------------------------------
measure_compile_ms() {
    local src="$1"
    local tmp_out
    tmp_out="$(mktemp)"

    # Use bash's EPOCHREALTIME when available (bash 5+), otherwise fall back to
    # python3 for sub-second precision.
    if [[ -n "${BASH_VERSINFO[0]}" && "${BASH_VERSINFO[0]}" -ge 5 ]]; then
        local t_start t_end
        t_start="${EPOCHREALTIME}"
        dmd -of="$tmp_out" "$src" 2>/dev/null
        t_end="${EPOCHREALTIME}"
        # Remove the temporary binary
        rm -f "$tmp_out"
        # Convert to milliseconds (integer)
        python3 -c "print(int(($t_end - $t_start) * 1000))"
    else
        # Fallback: use python3 to wrap the compilation and time it
        python3 - "$tmp_out" "$src" <<'PYEOF'
import subprocess, sys, time

tmp_out, src = sys.argv[1], sys.argv[2]
t0 = time.monotonic()
subprocess.run(["dmd", f"-of={tmp_out}", src], check=True,
               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
elapsed_ms = int((time.monotonic() - t0) * 1000)
print(elapsed_ms)
PYEOF
        rm -f "$tmp_out"
    fi
}

# ---------------------------------------------------------------------------
# Helper: compute the median of a list of integers passed as arguments.
# ---------------------------------------------------------------------------
median() {
    python3 - "$@" <<'PYEOF'
import sys
vals = sorted(int(x) for x in sys.argv[1:])
n = len(vals)
if n % 2 == 1:
    print(vals[n // 2])
else:
    print((vals[n // 2 - 1] + vals[n // 2]) // 2)
PYEOF
}

# ---------------------------------------------------------------------------
# Benchmark a single D source file; returns the median compile time in ms.
# ---------------------------------------------------------------------------
benchmark_file() {
    local label="$1"
    local src="$2"
    local times=()

    echo "  Benchmarking: $label"
    for i in $(seq 1 "$RUNS"); do
        local ms
        ms="$(measure_compile_ms "$src")"
        echo "    Run $i: ${ms} ms"
        times+=("$ms")
    done

    local med
    med="$(median "${times[@]}")"
    echo "  Median: ${med} ms"
    echo "$med"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
echo "=== dmd performance benchmark ==="
echo "Runs per benchmark: $RUNS"
echo ""

HELLO_MS="$(benchmark_file "hello" "$BENCHMARKS_DIR/hello.d")"
echo ""
TEMPLATE_MS="$(benchmark_file "template" "$BENCHMARKS_DIR/template.d")"
echo ""

# Write JSON output
python3 - "$OUTPUT_FILE" "$HELLO_MS" "$TEMPLATE_MS" <<'PYEOF'
import json, sys

output_file, hello_ms, template_ms = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
data = {
    "hello_compile_ms": hello_ms,
    "template_compile_ms": template_ms,
}
with open(output_file, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
print(f"Results written to {output_file}")
PYEOF

echo ""
echo "Done."
