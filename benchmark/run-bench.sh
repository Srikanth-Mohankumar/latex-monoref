#!/bin/bash
# Benchmark monoref (1 run) vs vanilla LaTeX (3 runs) at several sizes.
#
# Usage:            bash run-bench.sh
# Quick smoke test: SIZES="10" HYPER=0 bash run-bench.sh
#
# Sections ~= pages/2 (each generated section fills about two pages).
# Requires: lualatex (TeX Live), python3, /usr/bin/time, pdfinfo.
# Results:  build/bench-results.tsv
#           columns: job, run#, wall_seconds, max_RSS_MB, PDF_pages
set -u
cd "$(dirname "$0")"
SIZES="${SIZES:-50 125 250 500 1000}"
HYPER="${HYPER:-1}"

mkdir -p build
cp ../monoref.sty ../monoref.lua gen.py build/
cd build
OUT=bench-results.tsv
: > "$OUT"

run_one () {  # $1 job name, $2 run number
  /usr/bin/time -v lualatex -interaction=nonstopmode "$1.tex" > /dev/null 2> "$1.time"
  local wall rss pages
  wall=$(grep "Elapsed (wall clock)" "$1.time" | awk '{print $NF}')
  rss=$(grep "Maximum resident" "$1.time" | awk '{printf "%.0f", $NF/1024}')
  # normalize wall h:mm:ss / m:ss -> seconds
  wall=$(echo "$wall" | awk -F: '{ if (NF==3) print $1*3600+$2*60+$3; else if (NF==2) print $1*60+$2; else print $1 }')
  pages=$(pdfinfo "$1.pdf" 2>/dev/null | awk '/^Pages/{print $2}')
  echo -e "$1\t$2\t$wall\t$rss\t${pages:-NA}" | tee -a "$OUT"
}

for n in $SIZES; do
  python3 gen.py "$n" monoref  > "mono-$n.tex"
  python3 gen.py "$n" vanilla  > "van-$n.tex"
  rm -f "van-$n.aux" "van-$n.toc"
  run_one "mono-$n" 1
  run_one "van-$n" 1
  run_one "van-$n" 2
  run_one "van-$n" 3
  # correctness: the single monoref run must leave no unresolved references
  if command -v pdftotext > /dev/null; then
    unresolved=$(pdftotext "mono-$n.pdf" - 2>/dev/null | grep -o '??' | wc -l)
    echo "mono-$n unresolved refs: $unresolved"
  fi
done

if [ "$HYPER" = 1 ]; then
  python3 gen.py 500 monoref-hyper > mono-hyper-500.tex
  python3 gen.py 500 vanilla-hyper > van-hyper-500.tex
  rm -f van-hyper-500.aux van-hyper-500.toc van-hyper-500.out
  run_one mono-hyper-500 1
  run_one van-hyper-500 1
  run_one van-hyper-500 2
  run_one van-hyper-500 3
fi

echo DONE
