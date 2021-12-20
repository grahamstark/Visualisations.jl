using Visualisations
using Test

include( "../src/server_libs.jl")

ggs = ""

@testset "Server" begin
    # Write your tests here.
    global ggs
    d = Dict()
    ggs = submit_model( d )
    println( js )
     
end
