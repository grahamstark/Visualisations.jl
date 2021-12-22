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
    
    req=Dict{Any, Any}(:query => "it_basic_rate=20&it_higher_rate=41&it_top_rate=46&it_pa=12750&bi_adult=4800&bi_pensioner=8780&bi_pens_age=66&bi_child=3000&bi_adult_age=17&ubi_mtbens_keep_as_is=on&ubi_mtbens_abolish=on&ubi_mtbens_keep_housing=on&ubi_abolish_sick=&ubi_abolish_pensions=&ubi_abolish_esa=&ubi_abolish_others=&ubi_as_mt_income=&ubi_taxable=", 
        :method => "GET", 
        :parsed_querystring => 
            Dict{AbstractString, Any}(
                "bi_adult" => 4800, 
                "bi_pens_age" => 66, 
                "ubi_taxable" => "", 
                "ubi_as_mt_income" => "", 
                "it_top_rate" => 46, 
                "bi_pensioner" => 8780, 
                "ubi_abolish_sick" => "", 
                "ubi_abolish_pensions" => "", 
                "ubi_abolish_others" => "", 
                "ubi_mtbens_keep_housing" => "on", 
                "ubi_mtbens_abolish" => "on", 
                "it_pa" => 12750, 
                "ubi_abolish_esa" => "", 
                "it_basic_rate" => 20, 
                "bi_adult_age" => 17, 
                "it_higher_rate" => 41, 
                "ubi_mtbens_keep_as_is" => "on", 
                "bi_child" => 3000))

end