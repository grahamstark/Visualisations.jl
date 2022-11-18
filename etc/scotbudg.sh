#!/bin/sh
cd /home/graham_s/julia/vw/Visualisations/
# --procs=auto
/opt/julia/bin/julia -t4 --project=. src/scotbudg.jl
