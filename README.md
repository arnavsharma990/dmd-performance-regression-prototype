# dmd-performance-regression-prototype

A minimal performance regression checker for the [D compiler (dmd)](https://dlang.org/).  
It compiles small D programs, measures compile time, stores results as JSON, and
compares two runs to surface regressions.

---

## Project structure

```
.
├── benchmarks/
│   ├── hello.d       # Minimal "Hello, World!" program
│   └── template.d    # Template-heavy program to stress the compiler
├── run.sh            # Runs benchmarks and saves results.json
├── compare.py        # Compares two JSON result files
└── README.md
```

---

## Requirements

| Tool     | Minimum version |
|----------|----------------|
| `dmd`    | any recent release |
| `bash`   | 4+ (bash 5+ preferred for nanosecond timing) |
| `python3`| 3.9+ |

No third-party Python packages are required.

---

## Usage

### 1. Run benchmarks

```bash
chmod +x run.sh
./run.sh              # writes results.json
./run.sh current.json # write to a custom output file
```

Each benchmark is compiled **3 times** and the **median** compile time is
recorded.  Results are saved as JSON:

```json
{
  "hello_compile_ms": 40,
  "template_compile_ms": 1800
}
```

### 2. Compare two result files

```bash
# Capture a baseline first
./run.sh baseline.json

# … make changes to the compiler / environment …

# Capture the new results
./run.sh current.json

# Compare
python compare.py baseline.json current.json
```

---

## Example output

```
Comparing: baseline.json  →  current.json

Metric                    Baseline       Current       Change
────────────────────────────────────────────────────────────
Hello Compile Time          38.0 ms       39.2 ms      +3.2%  ⚠ REGRESSION
Template Compile Time     1820.0 ms     1799.8 ms      -1.1%

⚠  One or more metrics regressed by more than 2.0%.
```

Colour coding (when the terminal supports it):

* 🟢 **Green** — improvement (compile time decreased)
* 🔴 **Red**   — regression (compile time increased by more than 2 %)
* 🟡 **Yellow** — slight increase but within the 2 % threshold

The script exits with code `1` when a regression is detected, making it easy
to integrate into CI pipelines.

---

## How it works

1. **`run.sh`** invokes `dmd` to compile each benchmark to a temporary output
   file, measures elapsed time with millisecond precision, discards the
   binary, and repeats three times.  The median of the three runs is written
   to the JSON output file.

2. **`compare.py`** reads two JSON files (baseline and current), computes the
   percentage change for every metric, and prints a formatted table with
   colour-coded results.
