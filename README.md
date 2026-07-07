# monoref

Single-pass cross-references, page totals and a table of contents in **one
LuaLaTeX run** — no rerun, no `latexmk`, no `.aux` round-trip.

- **Author / maintainer:** Srikanth Mohankumar <srikanthmohankumar@gmail.com>
- **Version:** 1.3 (2026/07/07)
- **License:** LaTeX Project Public License (LPPL) 1.3c or later
- **Requires:** LuaLaTeX (the package stops with an error on other engines)
- **Status:** experimental

## What it does

Normally LaTeX needs at least two passes to resolve cross-references: the
first pass writes label values, section numbers and page numbers to the
`.aux` file, and the second pass reads them back. `monoref` removes
that round-trip for a useful subset of the problem by never shipping a page
out immediately. Every finished page is *held* in memory (via the
`shipout/before` hook and `\DiscardShipoutBox`); at `\end{document}`, when
all the facts are finally known, the still-unknown values are patched into
the held pages, which are then shipped.

It provides, resolved in a single run:

- `\ref{label}` — forward or backward section / equation numbers
- `\pageref{label}` — forward or backward page numbers (shipout-accurate)
- `\lastpage` — the total number of body pages
- a multi-level table of contents (`\section`, `\subsection`,
  `\subsubsection`) collected during the run and prepended at the end with
  roman folios, while the body keeps arabic numbering
- clickable links for refs, page refs and contents entries when
  **hyperref** is loaded (using the package's own named destinations, so
  linking stays single-pass and works for forward references)

## Two ideas make it work

1. **Fixed-width slots.** A not-yet-known value is typeset as a fixed-width
   `\hbox`. Because the box's outer width is frozen when the paragraph is
   broken, filling it later can never cause the line to reflow. The value is
   inserted, flush-right, at flush time.
2. **Shipout-accurate pages.** `\label` drops an invisible `\special` marker.
   When a page is held it is scanned for markers, and each label is stamped
   with the page it really landed on — avoiding the off-by-one you get from
   reading `\value{page}` at `\label` time (TeX's page builder is
   asynchronous).

## Installation

### From the sources

```
tex monoref.ins
```

This generates `monoref.sty`. Install **both**

```
monoref.sty   (generated)
monoref.lua   (shipped standalone)
```

into a directory LuaLaTeX searches, for example

```
TEXMFHOME/tex/lualatex/monoref/
```

then refresh the filename database with `mktexlsr` (or `texhash`).

To typeset the documentation:

```
lualatex monoref.dtx
```

## Usage

```latex
\documentclass{article}
\usepackage{hyperref}             % optional: clickable links
\usepackage{monoref}      % load AFTER hyperref; [notoc] disables the TOC
\begin{document}

\section{Introduction}\label{sec:intro}
See Section~\ref{sec:results} on page~\pageref{sec:results} (forward).
This document has \lastpage\ body pages.

\section{Results}\label{sec:results}
Back to Section~\ref{sec:intro} on page~\pageref{sec:intro}.

\end{document}
```

Compile with **one** run:

```
lualatex yourfile.tex
```

### Options and knobs

- Package option `notoc` — do not generate the contents page.
- Slot widths are font-relative templates: `\monorefreftemplate` (default
  `0.0.0`) sizes `\ref` slots and must be at least as wide as the widest
  forward (sub)section number; `\monorefpagetemplate` (default `000`) sizes
  `\pageref`/`\lastpage` slots. Redefine with `\renewcommand`, e.g.
  `\renewcommand\monorefreftemplate{0.0}`. At flush each slot collapses to
  the value's natural width and its line is re-justified, so even a
  single-digit value leaves no gap; the template only guides the
  original line break.
- Setting the length `\monorefslotwidth` to a positive value overrides both
  templates with one fixed width.
- Load **monoref after hyperref** to get clickable links.

## Limitations

This is a small, experimental package; please read these before using it on
a real document.

- It holds the whole document in memory until `\end{document}`.
- It redefines `\label`, `\ref`, `\pageref`, `\section`, `\subsection` and
  `\subsubsection`. It cooperates with **hyperref** for links, but because
  it replaces hyperref's versions of these commands, hyperref features that
  build on them (`\autoref`, `\nameref`, **cleveref**) are unavailable. It
  also conflicts with **titlesec** and **varioref**.
- Numbered-equation `\ref` works (including with **amsmath**), but
  `\eqref` and lists of figures/tables are not provided.
- A forward value wider than its slot template overflows.
- `\eqref`, hyperlinks and lists of figures/tables are not provided.
- Because it intercepts every `\shipout`, it is incompatible with other
  packages that manipulate shipout.

## Files

| File | Role |
|------|------|
| `monoref.dtx` | documented source (also builds the PDF manual) |
| `monoref.ins` | installer; generates the `.sty` |
| `monoref.lua` | Lua backend (shipped standalone) |
| `README.md` | this file |

## Examples

Runnable examples are in the `examples/` directory (compile each once with
LuaLaTeX):

| File | Shows |
|------|-------|
| `01-minimal.tex` | smallest possible use |
| `02-article.tex` | three heading levels, a numbered equation, forward/backward `\ref`/`\pageref`, page total, front TOC |
| `03-hyperref-links.tex` | clickable links via hyperref (`hidelinks`) |
| `04-notoc.tex` | the `notoc` option |
| `05-page-of-total.tex` | a "Page X of Y" footer with fancyhdr and `\lastpage` |
| `06-custom-slot-width.tex` | widening the slot templates |

## License

Copyright (C) 2026 Srikanth Mohankumar.

This work may be distributed and/or modified under the conditions of the
LaTeX Project Public License, either version 1.3c of this license or (at
your option) any later version: <http://www.latex-project.org/lppl.txt>.

This work has the LPPL maintenance status `maintained`. The Current
Maintainer is Srikanth Mohankumar.
