using Visualisations
using Test

include( "../src/uses.jl")
include( "../src/runner_libs.jl" )
include( "../src/display_constants.jl")
include( "../src/static_texts.jl")
include( "../src/table_libs.jl")
include( "../src/text_html_libs.jl")
include( "../src/server_libs.jl")

sys = load_system()
settings = BASE_STATE.settings



@testset "Server" begin
    # Write your tests here.
    d = Dict()
    ggs = submit_model( d )
    println( ggs )
end

@testset "Examples" begin    
    exres = calc_examples( sys, sys, settings )
    println( exres )
    extext = make_examples( exres )
    println( extext )
end

@testset "Parse Params" begin
    


end