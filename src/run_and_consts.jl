#
# Basic import for any visualisation that runs the full model.
# Create a base set of results, settings and parameters and
# import everything we might reasonably need.#
#
using ScottishTaxBenefitModel
using .BCCalcs
using .ModelHousehold
using .Utils
using .Definitions
using .SingleHouseholdCalculations
using .RunSettings
using .FRSHouseholdGetter
using .STBParameters
using .STBOutput
using .ExampleHelpers
using .Runner;
using .Utils:md_format

function load_system()::TaxBenefitSystem
	sys = load_file( joinpath( Definitions.MODEL_PARAMS_DIR, "sys_2021_22.jl" ))
	load_file!( sys, joinpath( Definitions.MODEL_PARAMS_DIR, "sys_2021-uplift-removed.jl"))
	weeklyise!( sys )
	return sys
end

struct BaseState
	sys          :: TaxBenefitSystem
	settings     :: Settings
	results      :: NamedTuple
	summary      :: NamedTuple
	gain_lose    :: NamedTuple
end

function initialise()::BaseState
    settings = Settings()
	settings.means_tested_routing = modelled_phase_in
    settings.run_name="run-$(date_string())"
	sys = load_system()
	results = do_one_run( settings, [sys] )
	settings.poverty_line = make_poverty_line( results.hh[1], settings )
	summary = summarise_frames( results, settings )
	popn = summary.inequality[1].total_population
	gainlose = ( 
		gainers=0.0, 
		losers=0.0,
		nc=popn, 
		popn = popn )	
	return BaseState( sys, settings, results, summary, gainlose )
end

const BASE_STATE = initialise()

function do_run( sys :: TaxBenefitSystem, init = false )::NamedTuple
	println( "running!!")
    results = do_one_run( BASE_STATE.settings, [sys] )
	outf = summarise_frames( results, BASE_STATE.settings )
	gl = make_gain_lose( BASE_STATE.results.hh[1], results.hh[1], BASE_STATE.settings ) 
	println( "gl=$gl");   
	return (summary=outf,gain_lose=gl)
end 

