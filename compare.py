#!/usr/bin/env python3
"""compare.py — Compare two benchmark result JSON files and report % changes.

Usage:
    python compare.py baseline.json current.json

Exit code:
    0  — no regressions found (or all changes within threshold)
    1  — at least one metric regressed by more than REGRESSION_THRESHOLD %
"""

import json
import sys

# Any metric that increases by more than this percentage is a regression.
REGRESSION_THRESHOLD = 2.0  # percent

# ---------------------------------------------------------------------------
# ANSI colour helpers (gracefully disabled when stdout is not a TTY)
# ---------------------------------------------------------------------------
_USE_COLOUR = sys.stdout.isatty()


def _colour(code: str, text: str) -> str:
    return f"\033[{code}m{text}\033[0m" if _USE_COLOUR else text


def red(text: str) -> str:
    return _colour("31;1", text)


def green(text: str) -> str:
    return _colour("32;1", text)


def yellow(text: str) -> str:
    return _colour("33;1", text)


def bold(text: str) -> str:
    return _colour("1", text)


# ---------------------------------------------------------------------------
# Pretty metric name mapping
# ---------------------------------------------------------------------------
METRIC_LABELS: dict[str, str] = {
    "hello_compile_ms": "Hello Compile Time",
    "template_compile_ms": "Template Compile Time",
}


def pretty_name(key: str) -> str:
    """Return a human-readable label for a metric key."""
    if key in METRIC_LABELS:
        return METRIC_LABELS[key]
    # Fallback: convert snake_case → Title Case
    return key.replace("_", " ").title()


# ---------------------------------------------------------------------------
# Core comparison logic
# ---------------------------------------------------------------------------

def load_json(path: str) -> dict:
    try:
        with open(path) as f:
            return json.load(f)
    except FileNotFoundError:
        print(f"Error: file not found: {path}", file=sys.stderr)
        sys.exit(2)
    except json.JSONDecodeError as exc:
        print(f"Error: invalid JSON in {path}: {exc}", file=sys.stderr)
        sys.exit(2)


def compare(baseline: dict, current: dict) -> bool:
    """Print a formatted comparison table.

    Returns True if any metric regressed beyond REGRESSION_THRESHOLD.
    """
    all_keys = sorted(set(baseline) | set(current))
    has_regression = False

    # Column widths for alignment
    label_width = max((len(pretty_name(k)) for k in all_keys), default=20)

    print(bold(f"\n{'Metric':<{label_width}}  {'Baseline':>12}  {'Current':>12}  {'Change':>10}"))
    print("─" * (label_width + 40))

    for key in all_keys:
        label = pretty_name(key)

        if key not in baseline:
            print(f"{label:<{label_width}}  {'—':>12}  {current[key]:>10} ms  {'(new)':>10}")
            continue

        if key not in current:
            print(f"{label:<{label_width}}  {baseline[key]:>10} ms  {'—':>12}  {'(removed)':>10}")
            continue

        base_val = float(baseline[key])
        curr_val = float(current[key])

        if base_val == 0:
            change_str = "N/A (base=0)"
            line = f"{label:<{label_width}}  {base_val:>10.1f} ms  {curr_val:>10.1f} ms  {change_str:>10}"
            print(line)
            continue

        pct = (curr_val - base_val) / base_val * 100.0

        if pct > REGRESSION_THRESHOLD:
            # Regression — show in red with a warning marker
            pct_str = red(f"+{pct:.1f}%  ⚠ REGRESSION")
            has_regression = True
        elif pct < 0:
            # Improvement — show in green
            pct_str = green(f"{pct:.1f}%")
        else:
            # Within acceptable range — neutral
            pct_str = yellow(f"+{pct:.1f}%") if pct > 0 else f"{pct:.1f}%"

        print(f"{label:<{label_width}}  {base_val:>10.1f} ms  {curr_val:>10.1f} ms  {pct_str}")

    print()

    if has_regression:
        print(red(f"⚠  One or more metrics regressed by more than {REGRESSION_THRESHOLD}%."))
    else:
        print(green("✓  No significant regressions detected."))

    print()
    return has_regression


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main() -> None:
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} baseline.json current.json", file=sys.stderr)
        sys.exit(2)

    baseline_path, current_path = sys.argv[1], sys.argv[2]
    baseline = load_json(baseline_path)
    current = load_json(current_path)

    print(bold(f"Comparing: {baseline_path}  →  {current_path}"))

    has_regression = compare(baseline, current)
    sys.exit(1 if has_regression else 0)


if __name__ == "__main__":
    main()
