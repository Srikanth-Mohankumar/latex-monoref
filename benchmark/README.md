# monoref benchmarks

Scripts and results for measuring `monoref`'s single-run cost against the
ordinary multi-run reference loop, plus a single-run bibliography proof of
concept. Written in response to review questions on the TUGboat article.

## Method

`gen.py` generates paired documents of ~N pages. Every section (~2 pages of
`lipsum` text) contains a backward `\ref`/`\pageref`, a forward
`\ref`/`\pageref`, and `\lastpage` — so every page carries unresolved
forward slots, the worst case for the patching phase.

- **monoref variant** — compiled **once**; monoref generates and prepends
  its own TOC.
- **vanilla variant** — plain LaTeX with `\tableofcontents`; compiled
  **three times**, which is what a stable TOC needs (the inserted TOC
  shifts every body page, so two runs are not enough).

`run-bench.sh` runs the matrix, records wall time and peak resident memory
via `/usr/bin/time -v`, and counts unresolved `??` in the monoref PDFs
(there must be none).

```
bash run-bench.sh                     # full matrix, ~4 minutes
SIZES="10" HYPER=0 bash run-bench.sh  # quick smoke test
```

## Results (2026-07-31)

TeX Live 2025, LuaHBTeX 1.22.0, Intel i5-1335U laptop, 16 GB RAM, Linux.
Single measurements on an otherwise idle machine (`results-2026-07-31.tsv`
is the raw data). Wall-clock seconds; RSS = peak resident memory.

| ~pages | monoref, 1 run | vanilla, 1 run | vanilla ×3 | monoref RSS | vanilla RSS |
|-------:|---------------:|---------------:|-----------:|------------:|------------:|
|    102 |          1.5 s |          1.3 s |      4.0 s |      164 MB |     ~150 MB |
|    253 |          3.0 s |          2.3 s |      7.0 s |      235 MB |     ~160 MB |
|    506 |          5.3 s |          4.1 s |     12.3 s |      312 MB |     ~165 MB |
|   1011 |          9.9 s |          7.5 s |     22.2 s |      451 MB |     ~170 MB |
|   2022 |         20.6 s |         14.6 s |     43.3 s |      778 MB |     ~205 MB |
| 1011 (hyperref) |  11.6 s |         7.9 s |     24.1 s |      467 MB |      170 MB |

Observations:

- **Time is linear** in page count: ~10 ms/page marginal for monoref vs
  ~7 ms/page per vanilla run — about 40% overhead on a single run, but
  ~34% faster than two vanilla runs and ~2.2× faster than three. No
  superlinear behaviour up to ~2000 pages: each held page is scanned once
  at hold and patched once at flush; no per-page work traverses the
  previously held pages.
- **Memory is the real ceiling**: holding costs ~0.32 MB/page of resident
  memory. ~1000 pages needs ~450 MB; extrapolating (not measured) to
  10 000 pages gives roughly 3.3 GB.
- **Correctness**: the 2022-page monoref document resolved all ~7000
  reference values in one run, zero `??`.

These are single measurements on a laptop — treat them as indicative, not
as a rigorous study.

## Bibliography proof of concept

`bib-poc.tex` shows single-run numbered citations riding on monoref's
existing slot machinery: `\bibitem` plants a monoref label (it sets
`\@currentlabel` to the citation number), and `\cite` becomes an ordinary
forward-reference slot. Forward citations, repeats, and `\pageref` into a
hand-written `thebibliography` all resolve in one `lualatex` run.

Not yet a package feature: multi-key and compressed citation lists
(`[3, 7–9]`) have unpredictable width, which the frozen-line-break slot
model cannot reserve for. Single-key citations fit the model exactly.
