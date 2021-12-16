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
using .STBIncomes
using .STBOutput
using .Monitor
using .ExampleHelpers
using .Runner
using .SimplePovertyCounts: GroupPoverty
using .GeneralTaxComponents: WEEKS_PER_YEAR, WEEKS_PER_MONTH
using .Utils:md_format

using UUIDs

PROGRESS = Dict{UUID,Any}()

function load_system()::TaxBenefitSystem
	sys = load_file( joinpath( Definitions.MODEL_PARAMS_DIR, "sys_2021_22.jl" ))
	#
	# Note that as of Budget21 removing these doesn't actually happen till May 2022.
	#
	load_file!( sys, joinpath( Definitions.MODEL_PARAMS_DIR, "sys_2021-uplift-removed.jl"))
	# uc taper to 55
	load_file!( sys, joinpath( Definitions.MODEL_PARAMS_DIR, "budget_2021_uc_changes.jl"))
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
	settings.uuid = UUIDs.uuid4()
	settings.means_tested_routing = modelled_phase_in
    settings.run_name="run-$(date_string())"
	settings.income_data_source = ds_frs
	settings.dump_frames = false
	settings.do_marginal_rates = true
	settings.requested_threads = 4
	sys = load_system()

	tot = 0
	obs = Observable( Progress(settings.uuid,"",0,0,0,0))
	of = on(obs) do p
		tot += p.step
		PROGRESS[p.uuid] = (progress=p,total=tot)
	end
	results = do_one_run( settings, [sys], obs )
	settings.poverty_line = make_poverty_line( results.hh[1], settings )
	summary = summarise_frames( results, settings )
	popn = summary.inequality[1].total_population
	gainlose = ( 
		gainers=0.0, 
		losers=0.0,
		nc=popn, 
		popn = popn )	
	delete!( PROGRESS, settings.uuid )
	return BaseState( sys, settings, results, summary, gainlose )
end

const BASE_STATE = initialise()

function do_run( sys :: TaxBenefitSystem, init = false )::NamedTuple
	obs = Observable( Progress("",0,0,0))
	tot = 0
	of = on(obs) do p
		tot += p.step
		PROGRESS[p.uuid] = (progress=p,total=tot)
	end
	setttings = deepcopy( BASE_STATE.settings )
	settings.uuid = UUIDs.uuid4()
    results = do_one_run( settings, [sys], obs )
	outf = summarise_frames( results, BASE_STATE.settings )
	gl = make_gain_lose( BASE_STATE.results.hh[1], results.hh[1], BASE_STATE.settings ) 
	println( "gl=$gl");   
	delete!( PROGRESS, settings.uuid )
	return (results=results, summary=outf,gain_lose=gl)
end 

