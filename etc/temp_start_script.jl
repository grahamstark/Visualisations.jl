using Pkg
cd( "/home/graham_s/julia/vw/Visualisations/")
Pkg.activate(".")
Pkg.develop( path="/home/graham_s/julia/DashBootstrapComponents/" )
Pkg.update()
include( "/home/graham_s/julia/vw/Visualisations/src/bc_demo.jl")