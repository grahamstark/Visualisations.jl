using Visualisations
using Test

include( "../src/server_libs.jl")

@testset "Server" begin
    # Write your tests here.
    d = Dict()
    js = submit_model( d )
    println( js )
end
