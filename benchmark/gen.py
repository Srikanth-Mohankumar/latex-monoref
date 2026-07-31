#!/usr/bin/env python3
"""Generate paired benchmark documents (monoref vs vanilla) of ~N pages.

Usage:  python3 gen.py <sections> <variant>
        variant: monoref | vanilla | monoref-hyper | vanilla-hyper

Each section fills roughly two pages (six lipsum paragraphs) and contains
a backward ref/pageref and a forward ref/pageref, so every page holds
unresolved forward slots -- the worst case for monoref's patching phase.
The monoref variant compiles in ONE run; the vanilla variant needs three
runs for a stable TOC (the inserted TOC shifts every body page).
"""
import sys

n = int(sys.argv[1])
variant = sys.argv[2]

body = []
for i in range(1, n + 1):
    prev_i = i - 1 if i > 1 else n
    next_i = i + 1 if i < n else 1
    body.append(rf"""
\section{{Benchmark section {i}}}\label{{sec:{i}}}
This is section~\ref{{sec:{i}}} on page~\pageref{{sec:{i}}} of \lastpage{{}} pages.
See section~\ref{{sec:{next_i}}} on page~\pageref{{sec:{next_i}}} (forward), and
section~\ref{{sec:{prev_i}}} on page~\pageref{{sec:{prev_i}}} (backward).
\lipsum[2-7]
\clearpage""")

hyper = r"\usepackage[hidelinks]{hyperref}" if variant.endswith("hyper") else "%"

if variant.startswith("monoref"):
    preamble = rf"""\documentclass{{article}}
\usepackage{{lipsum}}
{hyper}
\usepackage{{monoref}}
\renewcommand\monorefreftemplate{{0000}}
\renewcommand\monorefpagetemplate{{0000}}
"""
    toc = "%"  # monoref generates and prepends its own TOC
else:
    preamble = rf"""\documentclass{{article}}
\usepackage{{lipsum}}
{hyper}
\newcommand\lastpage{{\pageref{{lastpagelabel}}}}
\AtEndDocument{{\clearpage\label{{lastpagelabel}}}}
"""
    toc = r"\tableofcontents\clearpage"

print(preamble)
print(r"\begin{document}")
print(toc)
print("".join(body))
print(r"\end{document}")
