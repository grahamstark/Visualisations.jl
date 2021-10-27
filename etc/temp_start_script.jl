using Pkg
cd( "/home/graham_s/julia/vw/Visualisations/")
Pkg.develop( path="/home/graham_s/julia/DashBootstrapComponents/" )
Pkg.activate(".")
# Pkg.update()
include( "src/bc_demo.jl")