using Visualisations
using Test

include( "../src/uses.jl")
include( "../src/examples.jl")
include( "../src/runner_libs.jl" )
include( "../src/display_constants.jl")
include( "../src/static_texts.jl")
include( "../src/table_libs.jl")
include( "../src/text_html_libs.jl")
include( "../src/server_libs.jl")

sys = load_system()
settings = BASE_STATE.settings


@testset "Examples" begin    
    exres = calc_examples( sys, sys, settings )
    println( exres )
    extext = make_examples( exres )
    println( extext )
end

@testset "Parse Params" begin
    req=Dict{Any, Any}(
        :query => "it_basic_rate=20&it_higher_rate=41&it_top_rate=46&it_pa=12750&bi_adult=4800&bi_pensioner=8780&bi_pens_age=66&bi_child=3000&bi_adult_age=17&ubi_mtbens_keep_as_is=false&ubi_mtbens_abolish=false&ubi_mtbens_keep_housing=true&ubi_abolish_sick=true&ubi_abolish_pensions=false&ubi_abolish_esa=true&ubi_abolish_others=false&ubi_as_mt_income=true&ubi_taxable=true", 
        :method => "GET", 
        :parsed_querystring => Dict{AbstractString, Any}(
            "bi_adult" => 4800, 
            "bi_pens_age" => 66, 
            "ubi_taxable" => true, 
            "ubi_as_mt_income" => true, 
            "it_top_rate" => 46, 
            "bi_pensioner" => 8780, 
            "ubi_abolish_sick" => true, 
            "ubi_abolish_pensions" => false, 
            "ubi_abolish_others" => false, 
            "ubi_mtbens_keep_housing" => true, 
            "ubi_mtbens_abolish" => false, 
            "it_pa" => 12750, 
            "ubi_abolish_esa" => true, 
            "it_basic_rate" => 20, 
            "bi_adult_age" => 17, 
            "it_higher_rate" => 41, 
            "ubi_mtbens_keep_as_is" => false, 
            "bi_child" => 3000 ))
    msys = web_map_params( req )
    println( msys )
end

@testset "Queuing" begin

        for i in 1:10
            uuid = submit_job( sys, settings )
            @info "iter $i; submitted job $uuid "
            @info "iter $i IN_QUEUE=$IN_QUEUE"
            @info "iter $i OUT_QUEUE=$OUT_QUEUE"
        end

end