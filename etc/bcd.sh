#!/bin/sh
cd /home/microapi/julia/vw/Visualisations/
j=`which julia`
# --procs=auto
$j --project=.  src/bcd.jl
